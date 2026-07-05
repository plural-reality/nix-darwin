# Managed dotfiles: Claude Code, Codex, Gemini, Cursor
# Includes Xcode 26.3 Claude Agent MCP bridge for Reliable OMI / iOS BLE dev
{
  config,
  pkgs,
  lib,
  # Upstream repo's real on-disk path, injected by the launcher flake (null otherwise →
  # skills fall back to the Nix-store snapshot, keeping this module checkout-layout agnostic).
  upstreamPath ? null,
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

  context7McpServer = {
    command = "${pkgs.context7-mcp}/bin/context7-mcp";
    args = [ ];
  };

  # SCRAPBOX_SID is deliberately NOT here: the SID is a rotating session cookie
  # whose canonical source is the logged-in Chrome profile (self-healed into
  # ~/.claude/settings.local.json by scrapbox-sid-refresh.sh). Projecting it here
  # bakes a plaintext credential into the world-readable /nix/store settings.json
  # (leaked once already). cosense-fetch resolves the SID at runtime instead.
  sharedAgentEnvNames = [
    "GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND"
    "SOPS_AGE_KEY_FILE"
  ];

  inheritedAgentEnv = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = builtins.getAttr name config.home.sessionVariables;
    }) (builtins.filter (name: builtins.hasAttr name config.home.sessionVariables) sharedAgentEnvNames)
  );

  # One semantic environment, projected into each agent's native config format.
  # Agent teams are intentionally not enabled globally: their panel competes with
  # the working terminal. Opt into teams only from a one-off launch environment.
  sharedAgentEnv = inheritedAgentEnv;

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

    pruned_mcp_servers = {"apple-events", "beeper", "playwright"}

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

    for server_name in pruned_mcp_servers:
        if isinstance(document.get("mcp_servers"), MutableMapping):
            document["mcp_servers"].pop(server_name, None)

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

  # Skill attrs builder, parameterised by source strategy (sourceFor: name → path | derivation).
  # The two callers differ only in that strategy: Claude wants a live symlink, Codex a snapshot.
  mkSkillAttrs =
    baseDir: sourceFor:
    builtins.listToAttrs (
      map (name: {
        name = "${baseDir}/${name}";
        value.source = sourceFor name;
      }) sharedSkillNames
    );

  # Claude Code skill source. With upstreamPath (the upstream repo's real on-disk path,
  # injected by the launcher) ~/.claude/skills/<name> becomes an out-of-store symlink into
  # it, so editing prompt/claude-code/skills/<name>/SKILL.md takes effect immediately (no
  # apply). Falls back to the Nix-store snapshot when null — app design must not depend on
  # checkout layout; only the launcher knows where the repo lives. SKILL.md uses no @[…]
  # template refs, so the store expand is a no-op and both paths carry equivalent content.
  claudeSkillSource =
    name:
    if upstreamPath != null then
      config.lib.file.mkOutOfStoreSymlink "${upstreamPath}/prompt/claude-code/skills/${name}"
    else
      expandedSkillSources.${name};

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
      skillsAttrs,
    }:
    (mkInstructionAttr instructionPath instructionTemplate) // skillsAttrs;

  agentProfiles = [
    {
      instructionPath = ".claude/CLAUDE.md";
      instructionTemplate = ../prompt/claude-code/claude.md;
      # Claude Code 側: live symlink (upstreamPath 注入時)。 SKILL.md 編集が即反映 (apply 不要)
      skillsAttrs = mkSkillAttrs ".claude/skills" claudeSkillSource;
    }
    {
      instructionPath = ".codex/AGENTS.md";
      instructionTemplate = ../prompt/codex/agent.md;
      # Codex 側: build mediation。 frontmatter 補完が必要なため snapshot を経由
      skillsAttrs = mkSkillAttrs ".codex/skills" (name: codexSkillSources.${name});
    }
  ];

  agentFiles = builtins.foldl' (acc: profile: acc // (mkAgentAttrs profile)) { } agentProfiles;

  codexNotifyMacos = pkgs.writeShellApplication {
    name = "codex-notify-macos";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
      pkgs.llm-agents.codex
    ];
    text = ''
      set -u

      INPUT_JSON="''${1:-{}}"

      ${pkgs.nodejs_22}/bin/node --experimental-strip-types ${../scripts/codex-name.ts} --auto >/dev/null 2>&1 || true

      MSG="$(${pkgs.jq}/bin/jq -r '."last-assistant-message" // "Codex task completed"' <<<"$INPUT_JSON" 2>/dev/null || echo "Codex task completed")"
      MSG_SINGLE="$(printf "%s" "$MSG" | tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-180)"
      TITLE="Codex"

      /usr/bin/osascript - "$MSG_SINGLE" "$TITLE" <<'APPLESCRIPT'
      on run argv
        set msg to item 1 of argv
        set ttl to item 2 of argv
        display notification msg with title ttl
      end run
      APPLESCRIPT
    '';
  };

  codexManagedConfig = {
    approval_policy = "never";
    sandbox_mode = "danger-full-access";
    suppress_unstable_features_warning = true;

    model = "gpt-5.5";
    model_reasoning_effort = "xhigh";
    personality = "pragmatic";
    notify = [
      "${codexNotifyMacos}/bin/codex-notify-macos"
    ];

    tui = {
      status_line = [
        "model-name"
        "thread-id"
        "current-dir"
        "context-used"
        "five-hour-limit"
      ];
      terminal_title = [
        "spinner"
        "thread"
        "project"
      ];
    };

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
      context7 = context7McpServer;
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

  # Claude Code launches LIGHT by default — no standing ultracode. ultracode
  # (xhigh reasoning + automatic multi-agent workflow orchestration) is opt-in
  # per session via `ccx`; reserve it for review / hard tasks, not every turn.
  # Model and effort stay flexible per session — `/model`, or
  # `claude --model … --effort …` at launch — and are NOT pinned here.
  # `ccx` = heavy mode: same binary with ultracode injected at launch (merged
  # onto settings.json, not overriding it). tkgshn's personal layer re-points
  # `ccx` through the tmux launcher `cc` (see personal.nix).
  home.shellAliases.ccx = "claude --settings '{\"ultracode\":true}'";

  home.file = {
    # Gemini
    ".gemini/GEMINI.md".text = expandTemplate {
      templateScope = ../prompt;
      template = ../prompt/antigravity.md;
    };

    ".claude/settings.json".text = builtins.toJSON {
      # ultracode is intentionally NOT set here — it is opt-in per session via the
      # `ccx` alias above, not a standing default. Effort and model are likewise
      # chosen per session (`/model`, `--effort`) and are not pinned in this file.
      env = sharedAgentEnv;
      enableAutoMode = true;
      disableAgentView = true;
      skipDangerousModePermissionPrompt = true;
      statusLine = {
        type = "command";
        command = "bash ${config.home.homeDirectory}/.claude/statusline-command.sh";
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
      # Lifecycle hooks. Canonical home for SHARED hooks (User scope settings.json).
      # NOTE (corrected 2026-06-22): current Claude Code DOES read user-level
      # ~/.claude/settings.local.json, and hooks from both files MERGE ADDITIVELY
      # (no dedup) — empirically verified: the local-only Stop hook stop-reflect-nudge.py
      # writes ~/.claude/.reflect-nudge-*.done markers, and the local-only SessionStart
      # inject-world-model.sh injects the world model each session. So a hook registered
      # in BOTH files fires TWICE. Therefore: define each hook in exactly ONE place. Keep
      # shared/reproducible hooks here; do not duplicate them in settings.local.json.
      # ${homeDir} is interpolated by Nix; $(…)/$VAR are shell and pass through untouched.
      hooks =
        let
          homeDir = config.home.homeDirectory;
          script = name: "/bin/bash ${homeDir}/.claude/scripts/${name} 2>/dev/null || true";
          nodeScript =
            name:
            "${pkgs.nodejs_22}/bin/node --experimental-strip-types ${homeDir}/.claude/scripts/${name} 2>/dev/null || true";
        in
        {
          SessionStart = [
            {
              matcher = "startup";
              hooks = [
                {
                  type = "command";
                  command = script "nix-darwin-sync-check.sh";
                }
                {
                  type = "command";
                  command = script "init-prompt-on-new-project.sh";
                }
              ];
            }
            {
              # /new and /clear (and /reset) all fire source="clear".
              matcher = "clear";
              hooks = [
                {
                  type = "command";
                  command = script "init-prompt-on-new-project.sh";
                }
              ];
            }
            {
              # matcher omitted = all sources (startup/resume/clear/compact).
              hooks = [
                {
                  type = "command";
                  command = script "daily-report-remind.sh";
                }
                {
                  type = "command";
                  command = script "sid-freshness-check.sh";
                }
                # 世界モデル注入(2026-07-05 settings.local.json から昇格)。注入配線は nix 管理、
                # 中身 ~/.claude/context/world-model.md は「生きた状態ファイル」として意図的に
                # nix 外(MEMORY.md と同格)。ファイル不在なら fail-open。
                {
                  type = "command";
                  command = script "inject-world-model.sh";
                }
                # CRM 能動トリガ注入(同上昇格)。beeper-scrapbox-crm gateway(:8787)必須、停止時 fail-open。
                {
                  type = "command";
                  command = script "crm-due-inject.sh";
                }
                {
                  type = "command";
                  command = script "hook-fire-log.sh SessionStart";
                }
              ];
            }
          ];
          SessionEnd = [
            {
              hooks = [
                {
                  type = "command";
                  command = script "hook-fire-log.sh SessionEnd";
                }
                {
                  type = "command";
                  async = true;
                  command = script "daily-report-capture.sh";
                }
                # 終了セッションを LLM 要約・分類し summaries に蓄積 → Scrapbox 日付ページへ反映。
                # 再帰防止: 要約用 claude は CLAUDE_DAILY_SUMMARY=1 で起動され、本スクリプト先頭で skip。
                {
                  type = "command";
                  async = true;
                  command = script "session-summary.sh";
                }
              ];
            }
          ];
          PreCompact = [
            {
              hooks = [
                {
                  type = "command";
                  command = script "hook-fire-log.sh PreCompact";
                }
                {
                  type = "command";
                  async = true;
                  command = script "daily-report-capture.sh";
                }
                # 圧縮復旧: 圧縮の直前に marker を書く（現行 Claude Code に PostCompact
                # は無いので PreCompact を使う）。圧縮後 最初の UserPromptSubmit で
                # hook-compaction-recovery-restore.sh が拾い、plan/state file の再読込を促す。
                {
                  type = "command";
                  command = script "hook-compaction-recovery.sh";
                }
              ];
            }
          ];
          Notification = [
            {
              hooks = [
                {
                  type = "command";
                  async = true;
                  command = ''MSG=$(jq -r '.message // "あなたの操作を待っています"'); SUB=$(printf '%s' "$MSG" | grep -qi permission && echo "🔐 承認が必要です" || echo "⏳ 入力待ちです"); osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title "Claude Code" subtitle (item 1 of argv) sound name "Glass"' -e 'end run' "$SUB" "$MSG" 2>/dev/null || true'';
                }
              ];
            }
          ];
          UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = script "prompt-context-inject.sh";
                }
                # 圧縮復旧: PreCompact が残した marker を検出し、圧縮直後の 1 ターン目に
                # plan/state file の再読込・TaskList 確認を additionalContext で注入する（one-shot）。
                {
                  type = "command";
                  command = script "hook-compaction-recovery-restore.sh";
                }
                # 60% 通知: statusline が書いた warn marker を検出し、区切りでの
                # /compact-prep 実行提案を注入する（one-shot）。自動 compact を先回りで回避。
                {
                  type = "command";
                  command = script "hook-compact-prep-reminder.sh";
                }
              ];
            }
          ];
          Stop = [
            {
              hooks = [
                {
                  type = "command";
                  command = nodeScript "claude-codex-handoff-on-toolcall-leak.ts";
                }
                # Blocking gate: refuse to Stop while created tasks are still open
                # (pending/in_progress). Deliberately NOT wrapped in `|| true` / 2>/dev/null
                # — a non-zero exit (2) with a stderr reason is how a Stop hook blocks.
                # The script fails open on any error so it cannot wedge Stop, and fires at
                # most once per session (loud gate; the second Stop passes through).
                {
                  type = "command";
                  command = "${pkgs.python313}/bin/python3 ${homeDir}/.claude/scripts/stop-task-reconcile-gate.py";
                }
                # 自己学習 nudge(2026-07-05 settings.local.json から昇格)。実質的な作業をした
                # ターンの Stop を一度だけ block して self-learn skill を促す。手順の正本は skill。
                # decision JSON を stdout で返すため `script` ラッパ(stderr 抑制のみ)相当の素起動。
                {
                  type = "command";
                  command = "${pkgs.python313}/bin/python3 ${homeDir}/.claude/scripts/stop-reflect-nudge.py";
                }
                {
                  type = "command";
                  async = true;
                  command = ''DIR=$(jq -r '(.cwd // "") | sub("/+$"; "") | sub(".*/"; "")'); osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "Claude Code" subtitle "✅ 作業完了" sound name "Ping"' -e 'end run' "''${DIR:+''${DIR}の}応答が完了しました" 2>/dev/null || true'';
                }
              ];
            }
          ];
        };
    };

    # Status line: the script referenced by statusLine.command above. Co-located
    # with settings.json so the command and the script it runs are one source of
    # truth (was previously a hand-written, Nix-unmanaged file under ~/.claude).
    ".claude/statusline-command.sh" = {
      source = ../scripts/statusline-command.sh;
      executable = true;
    };

    ".claude/scripts/claude-codex-handoff-on-toolcall-leak.ts" = {
      source = ../scripts/claude-codex-handoff-on-toolcall-leak.ts;
      executable = true;
    };

    ".claude/scripts/prompt-context-inject.sh" = {
      source = ../scripts/prompt-context-inject.sh;
      executable = true;
    };

    ".claude/scripts/sid-freshness-check.sh" = {
      source = ../scripts/sid-freshness-check.sh;
      executable = true;
    };

    # Claude CLI global MCP is intentionally empty. Each Claude tmux tab forks
    # global servers, so heavyweight MCPs belong in task-specific tools instead.
    # ~/.claude.json is writable by Claude Code at runtime (startup counts, tips
    # history, caches, etc.) so keep it mutable and only replace mcpServers.

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
    MCP='${builtins.toJSON { }}'

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

  # (removed 2026-06-27) sharedAgentMemories: this used to symlink
  # ~/.claude/memories -> ~/.codex/memories. Claude's self-learning memory is the
  # harness-native auto-memory under ~/.claude/projects/<project>/memory/, which
  # Claude reads directly; ~/.claude/memories was a dead store that no Claude path
  # reads. Codex keeps ~/.codex/memories as its own store natively. The stale live
  # symlink is removed out-of-band (rm ~/.claude/memories).

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
