# Nix Agent Tooling Runbook

Read this before changing Nix/Home Manager, Claude/Codex prompts, skills, or shared agent scripts.

## Source Of Truth

- Shared skills live at `prompt/claude-code/skills/<name>/`.
- Shared scripts live at `scripts/` and are wired by `modules/shared-scripts.nix`.
- The raw `~/.claude/scripts/*` runtime payload lives at `scripts/claude/` and is wired by `modules/claude-agent-scripts.nix` (recursive symlink → `~/.claude/scripts/`).
- Agent prompt/config projection is owned by `modules/claude-code.nix`.
- Live files under `~/.claude/*` and `~/.codex/*` are generated outputs.

## ~/.claude Agent Environment Reproduction (for teammates, e.g. bluemo)

The agent environment under `~/.claude` is reproduced from this repo by three pieces:

| Live target | Repo source | Wiring |
|---|---|---|
| `~/.claude/skills/<name>/` | `prompt/claude-code/skills/<name>/` | auto-detected by `builtins.readDir` in `modules/claude-code.nix` |
| `~/.claude/scripts/*` (hook helpers, lifelog, daily-report, session tooling, Scrapbox/Beeper adapters, `lib/` + `calendar/` `reminders/` `meguro-pool/` `zwift-mode/`) | `scripts/claude/` | `modules/claude-agent-scripts.nix` (`home.file."./.claude/scripts"`, `recursive = true`) |
| nix-built CLIs (`scb-lint`, `codex-name`, statusline, Haskell stream tools) | `scripts/*.{mjs,ts,hs,sh}` | `modules/shared-scripts.nix` (`writeShellApplication` / `home.file."./.local/bin/X"`) |

**Per-user runtime state — NOT vendored, each machine provides its own:**
- `~/.config/beeper/token` — Beeper local-API bearer (Beeper Desktop must be running).
- `~/.config/beeper-to-scb/threads.json` — watched-group map for `beeper-to-scb`.
- SOPS-managed secrets stay in the secrets flow; never inline a secret value into `scripts/claude/`.

**External runtime deps assumed on PATH** (not all yet nix-provided — promote incrementally):
- `python3` (vendored scripts use stdlib only + local `scripts/claude/lib/normalize.py`).
- `node` for `pw.mjs` (its `playwright-core` dep is intentionally not vendored; `pw.mjs` is also known-broken — prefer the real-Chrome channel path).
- CLIs the scripts shell out to: `himalaya`, `cosense-fetch`, `scrapbox-write`, `jq`.

**This-machine convergence caveat (`.hmbak`):** on a machine that already has real files/dirs at the live targets (e.g. tkgshn's primary), Home Manager backs the pre-existing copy up to `*.hmbak` before symlinking. Fresh machines (bluemo) have no such conflict and link cleanly. Periodically clean accumulated `*.hmbak` to keep activation unblocked. This is separate from the migration above.
- Downstream flakes may import this repo from GitHub or from a local `path:` checkout while agent tooling is being tested. Keep that binding in the downstream flake, not in shared modules.

## Skill Change Fast Path

1. Add or edit only the canonical skill source:

```bash
$EDITOR prompt/claude-code/skills/<skill>/SKILL.md
```

2. Validate the skill locally:

```bash
ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f); puts "ok #{f}" }' \
  prompt/claude-code/skills/<skill>/SKILL.md

python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  prompt/claude-code/skills/<skill>
```

3. Stage new skill files before Nix validation.

Nix path inputs ignore untracked files. If a new skill is not staged or committed, downstream builds may keep using the old path hash.

```bash
git add prompt/claude-code/skills/<skill>
```

4. Validate the narrow output, not the whole flake:

```bash
nix build .#desktop-skills --no-link --print-out-paths
```

Confirm the ZIP exists when relevant:

```bash
ls -1 "$(nix build .#desktop-skills --no-link --print-out-paths)" | rg '^<skill>\.zip$'
```

## Downstream Refresh

When `/etc/nix-darwin` imports this repo by `path:`, refresh only that lock input before expecting the active system to see local source changes:

```bash
DOWNSTREAM="${DOWNSTREAM:-/etc/nix-darwin}"
nix flake update nix-darwin-upstream --flake "$DOWNSTREAM"
```

Then build the active system:

```bash
nix build "$DOWNSTREAM#darwinConfigurations.\"$(scutil --get LocalHostName)\".system" \
  --no-link --print-out-paths
```

Only activate after the build is known good:

```bash
sudo darwin-rebuild switch --flake "$DOWNSTREAM"
```

If the goal is only to inspect projected files, build first and inspect the store output instead of switching.

## Narrow Validation Patterns

Use targeted checks:

```bash
nix eval --json .#packages.aarch64-darwin.desktop-skills
nix build .#desktop-skills --no-link --print-out-paths
DOWNSTREAM="${DOWNSTREAM:-/etc/nix-darwin}"
nix build "$DOWNSTREAM#darwinConfigurations.\"$(scutil --get LocalHostName)\".system" --no-link --print-out-paths
```

Avoid broad checks during routine work:

```bash
nix flake show --all-systems
```

This repo has had Haskell/import-from-derivation failures on broad flake inspection. A broad failure there does not prove the touched agent tooling is broken.

## Live Projection Check

After activation, verify the live generated path:

```bash
readlink ~/.codex/skills/<skill>
readlink ~/.claude/skills/<skill>
```

If live links are shadowed by local directories, do not edit generated files. Move the shadowing directory aside, then rerun activation.

## Rules

- Do not duplicate a skill under both Claude and Codex trees. One canonical source feeds both.
- Do not edit `~/.codex/skills` or `~/.claude/skills` as source.
- Do not use `nix flake update` without an input name unless the task is dependency refresh.
- Do not use familiarity or DX as a reason to add another config boundary.
- Keep local path assumptions in the downstream launcher layer; shared modules should express the abstract contract.
