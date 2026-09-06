# System-managed Codex hooks. /etc/codex is a managed config layer, so Codex
# trusts this wiring without mutating per-user hook trust state.
{
  pkgs,
  lib,
  userConfig,
  ...
}:
let
  homeDirectory = "/Users/${userConfig.username}";
  sharedMemoryContext = pkgs.writeShellApplication {
    name = "codex-shared-memory-context";
    runtimeInputs = [ pkgs.python313 ];
    text = ''
      exec ${pkgs.python313}/bin/python3 ${../scripts/codex-shared-memory-context.py} "$@"
    '';
  };
  sharedMemoryHooks = map (chunkIndex: {
    type = "command";
    command = "${sharedMemoryContext}/bin/codex-shared-memory-context --memory-index ${homeDirectory}/.claude/projects/-Users-${userConfig.username}/memory/MEMORY.md --chunk-index ${toString chunkIndex}";
    timeout = 3;
  }) (lib.range 0 3);
  # Reuse the existing scripts unchanged. Pin their interpreters and shell
  # utilities instead of depending on the Desktop process's inherited PATH.
  shellHook =
    name: source: runtimeInputs: timeout:
    let
      runner = pkgs.writeShellApplication {
        inherit name runtimeInputs;
        text = ''
          exec ${pkgs.bash}/bin/bash ${source}
        '';
      };
    in
    {
      type = "command";
      command = "${runner}/bin/${name}";
      inherit timeout;
    };
  compactRecovery = pkgs.writeText "codex-compact-recovery.json" (
    builtins.toJSON {
      hookSpecificOutput = {
        hookEventName = "SessionStart";
        additionalContext = "現在の依頼・適用中の指示・正本を再確認し、要約の次手は仮説として照合してから続ける。利用可能なtask管理手段がある場合だけ必要範囲で確認し、存在しないTaskListやplan mode再確認を強制しない。";
      };
    }
  );
in
{
  environment.etc."codex/hooks.json".text = builtins.toJSON {
    hooks.SessionStart = [
      {
        hooks = sharedMemoryHooks ++ [
          (shellHook "codex-world-model-context" ../scripts/claude/inject-world-model.sh [
            pkgs.coreutils
            pkgs.jq
          ] 3)
          (shellHook "codex-daily-report-reminder" ../scripts/claude/daily-report-remind.sh [
            pkgs.coreutils
            pkgs.python313
          ] 3)
        ];
      }
      {
        matcher = "compact";
        hooks = [
          {
            type = "command";
            command = "${pkgs.coreutils}/bin/cat ${compactRecovery}";
            timeout = 3;
          }
        ];
      }
    ];
    hooks.UserPromptSubmit = [
      {
        hooks = [
          # The unchanged candidate search has its own five-second deadline.
          (shellHook "codex-prompt-context" ../scripts/prompt-context-inject.sh [
            pkgs.coreutils
            pkgs.jq
            pkgs.gawk
            pkgs.gnugrep
            pkgs.gnused
          ] 8)
        ];
      }
    ];
    hooks.PreToolUse = [
      {
        # Codex normalizes shell/unified exec to Bash for hook matching.
        # Preserve the synchronous exit-2 guard, including its original input.
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = "${pkgs.python313}/bin/python3 ${../scripts/claude/scrapbox-append-guard.py}";
            timeout = 3;
          }
        ];
      }
    ];
    hooks.PostToolUse = [
      {
        matcher = "mcp__claude_ai_Gmail__create_draft";
        hooks = [
          {
            type = "command";
            # This existing personal audit helper is not vendored upstream.
            # Preserve its target and matcher without broadening draft capture.
            command = "${pkgs.python313}/bin/python3 ${homeDirectory}/.claude/scripts/gmail-draft-diff/capture-draft.py";
            timeout = 3;
          }
        ];
      }
    ];
  };
}
