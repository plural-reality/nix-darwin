# Managed dotfiles: Claude Code, Codex, Gemini, Cursor
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
  xcodeAgentConfigDir = "Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig";

  # Shared skill source: Claude Code skillpack is wired to both Claude and Codex.
  sharedSkillsDir = ../prompt/claude-code/skills;
  sharedSkillEntries = builtins.readDir sharedSkillsDir;
  sharedSkillNames = builtins.filter (name: sharedSkillEntries.${name} == "directory") (
    builtins.attrNames sharedSkillEntries
  );
  expandedSkillSources = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = expandTemplatesDir {
        templateScope = ../prompt;
        src = sharedSkillsDir + "/${name}";
      };
    }) sharedSkillNames
  );

  codexSkillSources = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = pkgs.runCommand "codex-skill-${name}" { } ''
        mkdir -p "$out"
        cp -R ${expandedSkillSources.${name}}/. "$out/"

        if [ -f "$out/SKILL.md" ]; then
          first_line="$(${pkgs.coreutils}/bin/head -n 1 "$out/SKILL.md" || true)"
          if [ "$first_line" != "---" ]; then
            tmp="$out/SKILL.md.with-frontmatter"
            {
              echo "---"
              echo "name: ${name}"
              echo "description: Codex-compatible projection of the ${name} Claude skill."
              echo "---"
              echo
              cat "$out/SKILL.md"
            } > "$tmp"
            mv "$tmp" "$out/SKILL.md"
          fi
        fi
      '';
    }) sharedSkillNames
  );

  mkSkillAttrs =
    baseDir: skillSources:
    builtins.listToAttrs (
      map (name: {
        name = "${baseDir}/${name}";
        value.source = skillSources.${name};
      }) sharedSkillNames
    );

  mkInstructionAttr = targetPath: templatePath: {
    "${targetPath}".text = expandTemplate {
      templateScope = ../prompt;
      template = templatePath;
    };
  };

  mkAgentAttrs =
    {
      instructionPath,
      instructionTemplate,
      skillsPath,
      skillsSourceMap,
    }:
    (mkInstructionAttr instructionPath instructionTemplate)
    // (mkSkillAttrs skillsPath skillsSourceMap);

  agentProfiles = [
    {
      instructionPath = ".claude/CLAUDE.md";
      instructionTemplate = ../prompt/claude-code/claude.md;
      skillsPath = ".claude/skills";
      skillsSourceMap = expandedSkillSources;
    }
    {
      instructionPath = ".codex/AGENTS.md";
      instructionTemplate = ../prompt/codex/agent.md;
      skillsPath = ".codex/skills";
      skillsSourceMap = codexSkillSources;
    }
  ];

  agentFiles = builtins.foldl' (acc: profile: acc // (mkAgentAttrs profile)) { } agentProfiles;
in
{
  home.packages = [
    pkgs.llm-agents.claude-code # Claude Code CLI
  ];

  home.file = {
    # Gemini
    ".gemini/GEMINI.md".text = expandTemplate {
      templateScope = ../prompt;
      template = ../prompt/antigravity.md;
    };

    ".claude/settings.json".text = builtins.toJSON {
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };
      defaultMode = "bypassPermissions";
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
  // agentFiles;

  # Symlink ~/.claude/{commands,skills} → Xcode Agent config dir
  # so both CLI and Xcode Agent share the same commands/skills.
  # Xcode Agent ignores ~/.claude/commands/ and ~/.claude/skills/,
  # but reads from its own config dir.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Idempotent: replaces .mcpServers entirely (not deep-merge) so removals
    # from Nix propagate correctly. All other keys are preserved.
    CLAUDE_JSON="$HOME/.claude.json"
    MCP='${
      builtins.toJSON {
        XcodeBuildMCP = xcodeBuildMcpServer;
      }
    }'

    if [ -f "$CLAUDE_JSON" ]; then
      ${pkgs.jq}/bin/jq --argjson mcp "$MCP" '.mcpServers = $mcp' "$CLAUDE_JSON" \
        > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    else
      ${pkgs.jq}/bin/jq -n --argjson mcp "$MCP" '{ mcpServers: $mcp }' \
        > "$CLAUDE_JSON"
    fi
  '';

  home.activation.codexDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CODEX_CONFIG="$HOME/.codex/config.toml"
        mkdir -p "$HOME/.codex"

        if [ -f "$CODEX_CONFIG" ]; then
          # Keep existing settings, but declaratively pin top-level approval/sandbox defaults.
          ${pkgs.gnugrep}/bin/grep -v -E '^(approval_policy|sandbox_mode)[[:space:]]*=' "$CODEX_CONFIG" \
            > "$CODEX_CONFIG.body"
          {
            echo 'approval_policy = "never"'
            echo 'sandbox_mode = "danger-full-access"'
            echo
            cat "$CODEX_CONFIG.body"
          } > "$CODEX_CONFIG.tmp"
          mv "$CODEX_CONFIG.tmp" "$CODEX_CONFIG"
          rm -f "$CODEX_CONFIG.body"
        else
          cat > "$CODEX_CONFIG" <<'EOF'
    approval_policy = "never"
    sandbox_mode = "danger-full-access"
    EOF
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
