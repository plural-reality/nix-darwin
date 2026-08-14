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
  }) (lib.range 0 3);
in
{
  environment.etc."codex/hooks.json".text = builtins.toJSON {
    hooks.SessionStart = [
      {
        matcher = "startup";
        hooks = [
          {
            type = "command";
            command = "/bin/bash ${homeDirectory}/.claude/scripts/nix-darwin-sync-check.sh 2>/dev/null || true";
          }
        ];
      }
      {
        hooks = sharedMemoryHooks;
      }
    ];
  };
}
