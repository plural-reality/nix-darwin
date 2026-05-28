# Repository Instructions

Read `AGENTS.md` in this directory as the canonical repository guidance.

Claude-specific note: this repository uses `modules/claude-code.nix` to project the same shared prompt and skill source into Claude Code and Codex. Keep tool-specific settings in their native config formats; keep shared semantics in Nix attrsets or prompt snippets.
