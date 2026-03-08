# Managed dotfiles: Claude Code, Gemini, Cursor, Codex skills
# Includes Xcode 26.3 Claude Agent MCP bridge for Reliable OMI / iOS BLE dev
{ pkgs, lib, ... }:
let
  expandTemplate = import ../lib/expand-template.nix { inherit lib; };
  expandTemplatesDir = import ../lib/expand-templates-dir.nix { inherit pkgs lib; };

  xcodebuildmcp = import ../packages/xcodebuildmcp { inherit pkgs; };

  # XcodeBuildMCP: shared between CLI and Xcode Agent
  xcodeBuildMcpEnv = {
    INCREMENTAL_BUILDS_ENABLED = "true";
    XCODEBUILDMCP_DYNAMIC_TOOLS = "true";
  };

  # MCP server config fragment — single source of truth for both CLI and Xcode Agent.
  # Uses absolute Nix store path: no npx, no npm cache, fully hermetic.
  xcodeBuildMcpServer = {
    command = "${xcodebuildmcp}/bin/xcodebuildmcp";
    args = [ "mcp" ];
    env = xcodeBuildMcpEnv;
  };

  # Xcode Agent runs in a sandboxed environment without PATH inheritance.
  # All commands must use absolute Nix store paths.
  xcodeAgentConfigDir =
    "Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig";
in
{
  home.packages = [
    pkgs.llm-agents.claude-code # Claude Code CLI
  ];

  home.file =
    {
      # Gemini
      ".gemini/GEMINI.md".text = expandTemplate {
        templateScope = ../prompt;
        template = ../prompt/antigravity.md;
      };

      # Claude Code
      ".claude/CLAUDE.md".text = expandTemplate {
        templateScope = ../prompt;
        template = ../prompt/claude-code/claude.md;
      };
      ".claude/settings.json".text = builtins.toJSON {
        env = {
          CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        };
        teammateMode = "tmux";
        permissions = {
          allow = [
            "Bash(grep:*)"
            "Bash(find:*)"
            "Bash(cat:*)"
            "Bash(ls:*)"
            "Bash(head:*)"
            "Bash(tail:*)"
            "Bash(wc:*)"
            "Bash(sed:*)"
            "Bash(rg:*)"
            "Bash(fd:*)"
            "Bash(tree:*)"
            "Bash(echo:*)"
            "Bash(git log*)"
            "Bash(git diff*)"
            "Bash(git status*)"
            "Bash(git show*)"
            "Read"
            "Write"
            "WebSearch"
            "WebFetch"
          ];
        };
      };

      # MCP servers: ~/.claude.json is writable by Claude Code at runtime
      # (startup counts, tips history, caches, etc.) so we cannot manage it
      # as a read-only symlink. Instead, merge mcpServers via activation script.

      # Xcode Agent MCP config (absolute Nix store paths required)
      # Xcode Agent ignores ~/.claude.json and ~/.claude/settings.json.
      # ~/.claude/CLAUDE.md IS read by Xcode Agent — no duplication needed.
      "${xcodeAgentConfigDir}/.claude".text = builtins.toJSON {
        mcpServers = {
          XcodeBuildMCP = xcodeBuildMcpServer;
        };
      };

      # Cursor
      ".cursorrules".text = expandTemplate {
        templateScope = ../prompt;
        template = ../prompt/cursor.md;
      };
    }
    // (
      let
        skillsDir = ../prompt/claude-code/skills;
        entries = builtins.readDir skillsDir;
        skillNames = builtins.filter (name: entries.${name} == "directory") (
          builtins.attrNames entries
        );
        expandedSkillSources = builtins.listToAttrs (
          map (name: {
            inherit name;
            value = expandTemplatesDir {
              templateScope = ../prompt;
              src = skillsDir + "/${name}";
            };
          }) skillNames
        );
        mkSkillAttrs =
          baseDir:
          builtins.listToAttrs (
            map (name: {
              name = "${baseDir}/${name}";
              value.source = expandedSkillSources.${name};
            }) skillNames
          );
      in
      (mkSkillAttrs ".claude/skills") // (mkSkillAttrs ".codex/skills")
    );

  # Symlink ~/.claude/{commands,skills} → Xcode Agent config dir
  # so both CLI and Xcode Agent share the same commands/skills.
  # Xcode Agent ignores ~/.claude/commands/ and ~/.claude/skills/,
  # but reads from its own config dir.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Idempotent: replaces .mcpServers entirely (not deep-merge) so removals
    # from Nix propagate correctly. All other keys are preserved.
    CLAUDE_JSON="$HOME/.claude.json"
    MCP='${builtins.toJSON {
      XcodeBuildMCP = xcodeBuildMcpServer;
    }}'

    if [ -f "$CLAUDE_JSON" ]; then
      ${pkgs.jq}/bin/jq --argjson mcp "$MCP" '.mcpServers = $mcp' "$CLAUDE_JSON" \
        > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    else
      ${pkgs.jq}/bin/jq -n --argjson mcp "$MCP" '{ mcpServers: $mcp }' \
        > "$CLAUDE_JSON"
    fi
  '';

  home.activation.xcodeAgentSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    XCODE_DIR="$HOME/${xcodeAgentConfigDir}"
    mkdir -p "$XCODE_DIR"

    # commands: Xcode Agent dir → ~/.claude/commands (source of truth)
    if [ ! -e "$XCODE_DIR/commands" ]; then
      ln -s "$HOME/.claude/commands" "$XCODE_DIR/commands"
    fi

    # skills: Xcode Agent dir → ~/.claude/skills (source of truth, Nix-managed)
    if [ ! -e "$XCODE_DIR/skills" ]; then
      ln -s "$HOME/.claude/skills" "$XCODE_DIR/skills"
    fi
  '';

  # Xcode's own MCP bridge (for CLI → Xcode build/test/preview access):
  # claude mcp add --transport stdio xcode -- xcrun mcpbridge
}
