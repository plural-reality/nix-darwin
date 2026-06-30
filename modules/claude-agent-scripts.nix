# Vendored ~/.claude/scripts runtime payload so the agent environment reproduces on any machine.
#
# Source: scripts/claude/  (raw scripts: hook helpers, lifelog / daily-report / session tooling,
# Scrapbox & Beeper adapters, plus calendar/ reminders/ meguro-pool/ zwift-mode/ helper subdirs).
#
# `recursive = true` symlinks each file individually under ~/.claude/scripts/, preserving the
# source mode (executables stay +x via their git mode in the store) and leaving unmanaged files
# (caches, node_modules, *.hmbak) untouched — so this composes with anything else under that dir.
#
# NOT vendored (per-user runtime state / secrets — each machine provides its own):
#   ~/.config/beeper/token              (Beeper local-API bearer)
#   ~/.config/beeper-to-scb/threads.json (watched-group map)
#
# Runtime deps several scripts assume on PATH (document/provide separately; see
# docs/nix-agent-tooling-runbook.md): python3 (stdlib only), node (pw.mjs), and the
# himalaya / cosense-fetch / scrapbox-write CLIs.
{ ... }:
{
  home.file.".claude/scripts" = {
    source = ../scripts/claude;
    recursive = true;
  };
}
