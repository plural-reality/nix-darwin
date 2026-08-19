# Managed dotfiles: Claude Code, Codex, Gemini, Cursor
# Includes Xcode 26.3 Claude Agent MCP bridge for Reliable OMI / iOS BLE dev
{
  config,
  pkgs,
  lib,
  userConfig,
  # Upstream repo's real on-disk path, injected by the launcher flake (null otherwise →
  # skills fall back to the Nix-store snapshot, keeping this module checkout-layout agnostic).
  upstreamPath ? null,
  ...
}:
let
  expandTemplate = import ../lib/expand-template.nix { inherit lib; };
  expandTemplatesDir = import ../lib/expand-templates-dir.nix { inherit pkgs lib; };

  xcodebuildmcp = import ../packages/xcodebuildmcp { inherit pkgs; };
  freeeMcp = import ../packages/freee-mcp { inherit pkgs; };

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

  # freee MCP (会計・人事労務・請求書・工数管理・販売)。Published
  # pre-built ESMとtransitive npm closureをNixで固定し、runtime fetchをしない。
  freeeMcpServer = {
    command = "${freeeMcp}/bin/freee-mcp";
    args = [ ];
  };

  context7McpServer = {
    command = "${pkgs.context7-mcp}/bin/context7-mcp";
    args = [ ];
  };

  # Personal remote MCP bindings are declared once by the downstream flake and
  # projected into each client's native schema. OAuth credentials remain mutable
  # runtime state and are never copied into the Nix store.
  remoteMcpServers = userConfig.remoteMcpServers or { };
  codexPlugins = userConfig.codexPlugins or { };

  claudeCodeRemoteMcpServers = builtins.mapAttrs (_: server: {
    type = "http";
    inherit (server) url;
  }) remoteMcpServers;

  codexRemoteMcpServers = builtins.mapAttrs (
    _: server:
    {
      inherit (server) url;
      enabled = true;
    }
    // (server.codex or { })
  ) remoteMcpServers;

  codexMcpOauthCallback = userConfig.codexMcpOauthCallback or null;
  codexRouterEnabled = userConfig.codexRouterEnabled or false;

  # SCRAPBOX_SID is deliberately NOT here: the SID is a rotating session cookie
  # whose runtime cache is outside Nix and validated by scrapbox_session.py. Projecting it here
  # bakes a plaintext credential into the world-readable /nix/store settings.json
  # (leaked once already). Readers/writers use the same fail-closed runtime adapter.
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

  codexReasoningLevels = [
    {
      effort = "low";
      description = "Fast responses with lighter reasoning";
    }
    {
      effort = "medium";
      description = "Balances speed and reasoning depth for everyday tasks";
    }
    {
      effort = "high";
      description = "Greater reasoning depth for complex problems";
    }
    {
      effort = "xhigh";
      description = "Extra high reasoning depth for complex problems";
    }
    {
      effort = "max";
      description = "Maximum reasoning depth for the hardest problems";
    }
    {
      effort = "ultra";
      description = "Maximum reasoning with automatic task delegation";
    }
  ];

  mkCodexGpt56Model =
    {
      slug,
      displayName,
      description,
      defaultReasoningLevel,
      multiAgentVersion,
      priority,
    }:
    {
      inherit slug description priority;
      prefer_websockets = true;
      support_verbosity = true;
      default_verbosity = "low";
      apply_patch_tool_type = "freeform";
      web_search_tool_type = "text_and_image";
      input_modalities = [
        "text"
        "image"
      ];
      supports_image_detail_original = true;
      truncation_policy = {
        mode = "tokens";
        limit = 10000;
      };
      supports_parallel_tool_calls = true;
      tool_mode = "code_mode_only";
      multi_agent_version = multiAgentVersion;
      use_responses_lite = true;
      include_skills_usage_instructions = false;
      auto_review_model_override = null;
      context_window = 272000;
      max_context_window = 272000;
      auto_compact_token_limit = null;
      comp_hash = "3000";
      effective_context_window_percent = 95;
      reasoning_summary_format = "experimental";
      default_reasoning_summary = "none";
      supports_reasoning_summaries = true;
      display_name = displayName;
      default_reasoning_level = defaultReasoningLevel;
      supported_reasoning_levels = codexReasoningLevels;
      shell_type = "shell_command";
      visibility = "list";
      minimal_client_version = "0.144.0";
      supported_in_api = true;
      availability_nux = null;
      upgrade = null;
      experimental_supported_tools = [ ];
      supports_search_tool = true;
      additional_speed_tiers = [ "fast" ];
      service_tiers = [
        {
          id = "priority";
          name = "Fast";
          description = "1.5x speed, increased usage";
        }
      ];
      base_instructions = "";
    };

  mkCodexRoutedModel =
    {
      slug,
      displayName,
      description,
      contextWindow,
      defaultReasoningLevel,
      priority,
    }:
    (mkCodexGpt56Model {
      inherit
        slug
        description
        priority
        defaultReasoningLevel
        ;
      displayName = displayName;
      multiAgentVersion = "v1";
    })
    // {
      context_window = contextWindow;
      max_context_window = contextWindow;
      prefer_websockets = false;
      use_responses_lite = false;
      input_modalities = [ "text" ];
      supports_image_detail_original = false;
      additional_speed_tiers = [ ];
      service_tiers = [ ];
    };

  codexModelCatalogFile = pkgs.writeText "codex-model-catalog.json" (
    builtins.toJSON {
      models = [
        (mkCodexGpt56Model {
          slug = "gpt-5.6-sol";
          displayName = "GPT-5.6 Sol";
          description = "Latest frontier agentic coding model.";
          defaultReasoningLevel = "low";
          multiAgentVersion = "v2";
          priority = 1;
        })
        (mkCodexGpt56Model {
          slug = "gpt-5.6-terra";
          displayName = "GPT-5.6 Terra";
          description = "Balanced agentic coding model for everyday work.";
          defaultReasoningLevel = "medium";
          multiAgentVersion = "v2";
          priority = 2;
        })
        (mkCodexGpt56Model {
          slug = "gpt-5.6-luna";
          displayName = "GPT-5.6 Luna";
          description = "Fast and affordable agentic coding model.";
          defaultReasoningLevel = "medium";
          multiAgentVersion = "v1";
          priority = 3;
        })
      ]
      ++ lib.optionals codexRouterEnabled [
        (mkCodexRoutedModel {
          slug = "deepseek/deepseek-v4-pro";
          displayName = "DeepSeek V4 Pro";
          description = "DeepSeek V4 Pro via OpenRouter.";
          contextWindow = 1048576;
          defaultReasoningLevel = "medium";
          priority = 4;
        })
        (mkCodexRoutedModel {
          slug = "deepseek/deepseek-v4-flash";
          displayName = "DeepSeek V4 Flash";
          description = "DeepSeek V4 Flash via OpenRouter.";
          contextWindow = 1048576;
          defaultReasoningLevel = "low";
          priority = 5;
        })
        (mkCodexRoutedModel {
          slug = "deepseek/deepseek-v3.2";
          displayName = "DeepSeek V3.2";
          description = "DeepSeek V3.2 via OpenRouter.";
          contextWindow = 163840;
          defaultReasoningLevel = "medium";
          priority = 6;
        })
        (mkCodexRoutedModel {
          slug = "qwen/qwen3.8-max";
          displayName = "Qwen3.8 Max";
          description = "Qwen3.8 Max via OpenRouter.";
          contextWindow = 1000000;
          defaultReasoningLevel = "medium";
          priority = 7;
        })
        (mkCodexRoutedModel {
          slug = "moonshotai/kimi-k3";
          displayName = "Kimi K3";
          description = "MoonshotAI Kimi K3 via OpenRouter.";
          contextWindow = 1048576;
          defaultReasoningLevel = "medium";
          priority = 8;
        })
      ];
    }
  );

  codexConfigPython = pkgs.python313.withPackages (ps: [ ps.tomlkit ]);

  codexConfigMergeScript = pkgs.writeText "merge-codex-config.py" (
    builtins.readFile ../scripts/merge-codex-config.py
  );

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

  # Codex の turn 終了フック。以前はここでデスクトップ通知も出していたが、通知は全廃した
  # (2026-08-08)。残っている責務はセッションの自動命名だけなので、名前もそれに合わせる。
  # `notify` is the legacy turn-complete callback used only for task naming.
  # Lifecycle hooks are independently owned by modules/codex-hooks.nix.
  codexTurnEndNameHook = pkgs.writeShellApplication {
    name = "codex-name-on-turn-end";
    runtimeInputs = [ pkgs.llm-agents.codex ];
    text = ''
      set -u
      ${pkgs.nodejs_22}/bin/node --experimental-strip-types ${../scripts/codex-name.ts} --auto >/dev/null 2>&1 || true
    '';
  };

  codexProfileConfigs = {
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
    maximum-local = {
      approval_policy = "never";
      sandbox_mode = "danger-full-access";
      model_reasoning_effort = "ultra";
    };
  };

  codexProfileConfigFiles = lib.mapAttrs (
    name: profile: pkgs.writeText "codex-${name}-profile.json" (builtins.toJSON profile)
  ) codexProfileConfigs;

  codexManagedConfig = {
    approval_policy = "never";
    # The workspace is the ambient shell/filesystem mutation boundary. MCP,
    # plugins, and external APIs keep separate capability/consent boundaries.
    # Wider filesystem writes are injected per task (`--add-dir`) or selected
    # through an explicit profile.
    sandbox_mode = "workspace-write";
    suppress_unstable_features_warning = true;

    features.multi_agent_v2 = {
      enabled = true;
    };

    model_catalog_json = "${codexModelCatalogFile}";
    model = "gpt-5.6-terra";
    model_reasoning_effort = "high";
    personality = "pragmatic";
    notify = [
      "${codexTurnEndNameHook}/bin/codex-name-on-turn-end"
    ];

    memories = {
      generate_memories = false;
      use_memories = false;
    };

    features = {
      hooks = true;
      memories = false;
    };

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

    mcp_servers = {
      XcodeBuildMCP = xcodeBuildMcpServer // {
        enabled = false;
      };
      freee = freeeMcpServer // {
        enabled = false;
      };
      context7 = context7McpServer // {
        enabled = false;
      };
    }
    // codexRemoteMcpServers;

    plugins = {
      "computer-use@openai-bundled" = {
        enabled = true;
      };
      "browser@openai-bundled" = {
        enabled = false;
      };
      "chrome@openai-bundled" = {
        enabled = true;
      };
    }
    // codexPlugins;
  }
  // lib.optionalAttrs (codexMcpOauthCallback != null) {
    mcp_oauth_callback_port = codexMcpOauthCallback.port;
    mcp_oauth_callback_url = codexMcpOauthCallback.url;
  }
  // lib.optionalAttrs codexRouterEnabled {
    openai_base_url = "http://127.0.0.1:21434/v1";
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
        # Sessions start in full auto (== --dangerously-skip-permissions).
        # Must live in USER-scope settings.json (this file) to take effect.
        defaultMode = "bypassPermissions";
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
          # Notification hook は登録しない(2026-08-08 廃止)。入力待ち・承認待ちのデスクトップ
          # 通知だけが唯一の用途だったため、通知全廃と同時にフックごと外した。
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
                # 応答完了のデスクトップ通知はここにあったが廃止(2026-08-08)。
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
    MCP='${builtins.toJSON claudeCodeRemoteMcpServers}'

    if [ -f "$CLAUDE_JSON" ]; then
      ${pkgs.jq}/bin/jq --argjson mcp "$MCP" '.mcpServers = $mcp' "$CLAUDE_JSON" \
        > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    else
      ${pkgs.jq}/bin/jq -n --argjson mcp "$MCP" '{ mcpServers: $mcp }' \
        > "$CLAUDE_JSON"
    fi
  '';

  home.activation.codexDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CODEX_HOME="$HOME/.codex"
    mkdir -p "$CODEX_HOME"
    ${codexConfigPython}/bin/python ${codexConfigMergeScript} ${codexManagedConfigFile} "$CODEX_HOME/config.toml"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: configFile: ''
        ${codexConfigPython}/bin/python ${codexConfigMergeScript} ${configFile} "$CODEX_HOME/${name}.config.toml"
      '') codexProfileConfigFiles
    )}
    ${pkgs.coreutils}/bin/chmod 600 "$CODEX_HOME/config.toml" "$CODEX_HOME"/*.config.toml
  '';

  home.activation.removeLegacyCodexHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LEGACY_HOOKS="$HOME/.codex/hooks.json"
    LEGACY_HOOKS_SHA256="0dd0a2d540cfbef57e7b68473298aa68b140da6408475b21a39219bcf2ca6d3c"
    if [ -f "$LEGACY_HOOKS" ] && [ ! -L "$LEGACY_HOOKS" ] \
      && [ "$(${pkgs.coreutils}/bin/sha256sum "$LEGACY_HOOKS" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)" = "$LEGACY_HOOKS_SHA256" ]; then
      ${pkgs.coreutils}/bin/rm "$LEGACY_HOOKS"
    fi
  '';

  home.activation.removeLegacyAgentShadows = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LEGACY_MEMORY="$HOME/.claude/memories"
    LEGACY_AGENTS="$HOME/AGENTS.md"
    LEGACY_AGENTS_SHA256="d673e46c7c9790b83d17425f736599421809df1d593a3c883c5c6232d8dd34f7"

    if [ -L "$LEGACY_MEMORY" ] && [ "$(${pkgs.coreutils}/bin/readlink "$LEGACY_MEMORY")" = "$HOME/.codex/memories" ]; then
      ${pkgs.coreutils}/bin/unlink "$LEGACY_MEMORY"
    fi

    if [ -f "$LEGACY_AGENTS" ] && [ ! -L "$LEGACY_AGENTS" ] \
      && [ "$(${pkgs.coreutils}/bin/sha256sum "$LEGACY_AGENTS" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)" = "$LEGACY_AGENTS_SHA256" ]; then
      ${pkgs.coreutils}/bin/rm "$LEGACY_AGENTS"
    fi
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
