# Repository Instructions

This repository is the shared Nix/Home Manager source for local agent tooling.

## Source Of Truth

- Shared Claude Code and Codex files are generated from `modules/claude-code.nix`.
- Agent prompts and skills live under `prompt/`.
- Shared CLI tools live under `scripts/` and are wired through `modules/shared-scripts.nix`.
- Personal machine bindings belong in the downstream flake, not in this repository.

## Development Rules

- Before changing Nix/Home Manager, shared agent prompts, skills, or scripts, read `docs/nix-agent-tooling-runbook.md` and use its narrow validation path.
- Use `nix fmt` before finishing Nix changes.
- Keep tool installation declarative through Nix/Home Manager.
- Treat `~/.claude/*` and `~/.codex/*` generated files as outputs, not sources.
- Preserve mutable runtime state such as Codex project trust, plugin marketplace timestamps, and auth caches unless the task explicitly targets them.
- Do not embed new secret values in Nix, prompts, or generated dotfiles.
