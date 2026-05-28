# Claude Code / Codex Environment Alignment

## Pattern

The agent environment is a projection pipeline:

`Nix attrsets -> Claude JSON / Codex TOML / Xcode Agent JSON`

The semantic contract belongs in Nix and prompt snippets. Concrete config files are adapters.

## Managed State

- `modules/claude-code.nix` owns generated Claude Code and Codex instruction files.
- `prompt/claude-code/skills` is the shared skill source.
- Claude Code receives `~/.claude/settings.json`.
- Codex receives stable defaults by merging a Nix-generated JSON document into `~/.codex/config.toml`.
- Xcode Agent receives the same XcodeBuildMCP server definition with absolute Nix store paths.

## Mutable State

Do not force these through Nix unless they become team policy:

- Codex project trust entries
- plugin marketplace timestamps
- login and auth cache files
- notices and one-off migration prompts
- local experiments under `~/.codex/skills` or `~/.claude/skills`

## Compatibility Rules

- `AGENTS.md` is the Codex-native repo rule file.
- `CLAUDE.md` is the Claude Code-native repo rule file.
- Either file may act as compatibility input when a repository has only one of them.
- Claude command definitions and Codex subagents are not the same abstraction. Translate by behavior, not by filename.
- Permission syntax is tool-specific: Claude allowlists are not Codex sandbox policy.

## Current Defaults

The default local profile remains optimized for this machine's trusted local workflows:

- Codex approval policy: `never`
- Codex sandbox mode: `danger-full-access`
- Claude Code auto mode: enabled
- Claude Code dangerous permission prompt: skipped

Safer Codex profiles can be added without changing the default by adding named `[profiles.*]` entries to the Nix-managed Codex config projection.

The current projection includes:

- `safe`: `on-request` + `workspace-write`
- `fast-local`: `never` + `danger-full-access`
