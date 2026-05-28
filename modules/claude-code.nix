# Managed dotfiles: Claude Code, Codex, Gemini, Cursor
# Includes Xcode 26.3 Claude Agent MCP bridge for Reliable OMI / iOS BLE dev
{
  config,
  pkgs,
  lib,
  ...
}:
let
  expandTemplate = import ../lib/expand-template.nix { inherit lib; };
  expandTemplatesDir = import ../lib/expand-templates-dir.nix { inherit pkgs lib; };

  xcodebuildmcp = import ../packages/xcodebuildmcp { inherit pkgs; };

  # Claude Desktop uploadable skill ZIPs
  desktopSkills = import ../packages/desktop-skills {
    inherit pkgs;
    skillsDir = ../prompt/claude-code/skills;
  };

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

  # freee MCP (会計・人事労務・請求書・工数管理・販売)
  # Why npx: upstream は bun-only (bun.lock のみ)。
  # buildNpmPackage 不可、bun2nix は将来の課題。
  # 版は Nix 文字列で固定 → version drift は封じ込め済み。
  freeeMcpVersion = "0.26.7";
  freeeMcpServer = {
    command = "${pkgs.nodejs_22}/bin/npx";
    args = [
      "-y"
      "-p"
      "freee-mcp@${freeeMcpVersion}"
      "freee-mcp"
    ];
  };

  sharedAgentEnvNames = [
    "CLAUDE_CODE_EFFORT_LEVEL"
    "GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND"
    "SCRAPBOX_SID"
    "SOPS_AGE_KEY_FILE"
  ];

  inheritedAgentEnv = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = builtins.getAttr name config.home.sessionVariables;
    }) (builtins.filter (name: builtins.hasAttr name config.home.sessionVariables) sharedAgentEnvNames)
  );

  # One semantic environment, projected into each agent's native config format.
  sharedAgentEnv = {
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
  }
  // inheritedAgentEnv;

  codexConfigPython = pkgs.python313.withPackages (ps: [ ps.tomlkit ]);

  codexConfigMergeScript = pkgs.writeText "merge-codex-config.py" ''
    from collections.abc import MutableMapping
    from datetime import datetime, timezone
    from pathlib import Path
    import json
    import sys

    import tomlkit

    managed_path = Path(sys.argv[1])
    config_path = Path(sys.argv[2])

    def merge(target, source):
        for key, value in source.items():
            if isinstance(value, dict):
                current = target.get(key)
                target[key] = merge(
                    current if isinstance(current, MutableMapping) else tomlkit.table(),
                    value,
                )
            else:
                target[key] = value
        return target

    managed = json.loads(managed_path.read_text())

    try:
        document = tomlkit.parse(config_path.read_text()) if config_path.exists() else tomlkit.document()
    except Exception as exc:
        backup_path = config_path.with_suffix(
            f".toml.invalid-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
        )
        config_path.rename(backup_path)
        print(f"warning: moved invalid Codex config to {backup_path}: {exc}", file=sys.stderr)
        document = tomlkit.document()

    config_path.write_text(tomlkit.dumps(merge(document, managed)))
  '';

  # Xcode Agent runs in a sandboxed environment without PATH inheritance.
  # All commands must use absolute Nix store paths.
  xcodeAgentConfigDir = "Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig";

  # Shared agents & commands: deployed to ~/.claude/{agents,commands}
  sharedAgentsDir = ../prompt/claude-code/agents;
  sharedCommandsDir = ../prompt/claude-code/commands;

  # Enumerate files recursively under a directory, returning relative paths.
  # e.g. agents/cl/foo.md → ".claude/agents/cl/foo.md"
  mkDirFileAttrs =
    targetPrefix: srcDir:
    let
      # Read top-level entries (namespace dirs like "cl/")
      topEntries = builtins.readDir srcDir;
      namespaces = builtins.filter (n: topEntries.${n} == "directory") (builtins.attrNames topEntries);
      mkNamespaceAttrs =
        ns:
        let
          nsEntries = builtins.readDir (srcDir + "/${ns}");
          files = builtins.filter (f: nsEntries.${f} == "regular") (builtins.attrNames nsEntries);
        in
        builtins.listToAttrs (
          map (f: {
            name = "${targetPrefix}/${ns}/${f}";
            value.source = srcDir + "/${ns}/${f}";
          }) files
        );
    in
    builtins.foldl' (acc: ns: acc // (mkNamespaceAttrs ns)) { } namespaces;

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

  codexManagedConfig = {
    approval_policy = "never";
    sandbox_mode = "danger-full-access";
    suppress_unstable_features_warning = true;

    model = "gpt-5.5";
    model_reasoning_effort = "xhigh";
    personality = "pragmatic";
    notify = [
      "bash"
      "/Users/tkgshn/.codex/notify_macos.sh"
    ];

    shell_environment_policy = {
      "inherit" = "core";
      set = sharedAgentEnv;
    };

    profiles = {
      safe = {
        approval_policy = "on-request";
        sandbox_mode = "workspace-write";
        model_reasoning_effort = "medium";
      };
      fast-local = {
        approval_policy = "never";
        sandbox_mode = "danger-full-access";
        model_reasoning_effort = "low";
      };
    };

    mcp_servers = {
      XcodeBuildMCP = xcodeBuildMcpServer;
      freee = freeeMcpServer;
    };

    plugins = {
      "computer-use@openai-bundled" = {
        enabled = false;
      };
      "browser@openai-bundled" = {
        enabled = false;
      };
      "chrome@openai-bundled" = {
        enabled = true;
      };
    };
  };

  codexManagedConfigFile = pkgs.writeText "codex-managed-config.json" (
    builtins.toJSON codexManagedConfig
  );
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
      effortLevel = "max";
      env = sharedAgentEnv;
      enableAutoMode = true;
      skipDangerousModePermissionPrompt = true;
      teammateMode = "tmux";
      statusLine = {
        type = "command";
        command = "bash /Users/tkgshn/.claude/statusline-command.sh";
      };
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
          "Bash(printf:*)"
          "Bash(jq:*)"
          "Bash(freee-call:*)"
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

    # Claude Desktop: skill ZIPs for upload (⌘⇧G → ~/.claude/desktop-skills)
    ".claude/desktop-skills".source = desktopSkills;

    # Cursor
    ".cursorrules".text = expandTemplate {
      templateScope = ../prompt;
      template = ../prompt/cursor.md;
    };
  }
  // agentFiles
  // (mkDirFileAttrs ".claude/agents" sharedAgentsDir)
  // (mkDirFileAttrs ".claude/commands" sharedCommandsDir);

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
        freee = freeeMcpServer;
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
    ${codexConfigPython}/bin/python ${codexConfigMergeScript} ${codexManagedConfigFile} "$CODEX_CONFIG"
  '';

  home.activation.xcodeAgentSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    XCODE_DIR="$HOME/${xcodeAgentConfigDir}"
    mkdir -p "$XCODE_DIR"

    # commands: Xcode Agent dir → ~/.claude/commands (source of truth)
    # Use -L to detect dangling symlinks (which -e misses)
    if [ ! -L "$XCODE_DIR/commands" ] && [ ! -e "$XCODE_DIR/commands" ]; then
      ln -s "$HOME/.claude/commands" "$XCODE_DIR/commands"
    fi

    # skills: Xcode Agent dir → ~/.claude/skills (source of truth, Nix-managed)
    if [ ! -L "$XCODE_DIR/skills" ] && [ ! -e "$XCODE_DIR/skills" ]; then
      ln -s "$HOME/.claude/skills" "$XCODE_DIR/skills"
    fi
  '';

  # Xcode's own MCP bridge (for CLI → Xcode build/test/preview access):
  # claude mcp add --transport stdio xcode -- xcrun mcpbridge
}
