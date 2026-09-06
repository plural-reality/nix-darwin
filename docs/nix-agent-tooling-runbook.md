# Nix Agent Tooling Runbook

Read this before changing Nix/Home Manager, Claude/Codex prompts, skills, or shared agent scripts.

## Source Of Truth

- Shared skills live at `prompt/claude-code/skills/<name>/`.
- Shared memory = Claude harness-native `~/.claude/projects/<project>/memory/` (canonical). Claude injects it natively; a Nix-managed Codex SessionStart hook projects the bounded pointer index. Codex native memory generation/use is enabled independently; this does not migrate or replace the shared Claude memory store; never route shared writes into `~/.codex/memories`.
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

**External runtime deps** — the agent CLIs are now nix-provided so a fresh machine has them:
- `python3` (stdlib only + local `scripts/claude/lib/normalize.py`), `node`, `ffmpeg`, `imagemagick`, `poppler`(pdftotext), `ripgrep`, `fzf` — `modules/base.nix`.
- `jq`, `himalaya`, `pandoc` — added to `modules/base.nix` (were system/Homebrew-only).
- `cosense-fetch`, `scrapbox-write`, `scrapbox-rename`, `scb-lint`, `codex-name` — `modules/shared-scripts.nix`.
- Still not nix-managed (add per-skill-need, not forced into the base closure): `tesseract`/`tesseract-lang` (OCR), `terminal-notifier`, and `whisper-cpp`. The legacy `pw`/`pw.mjs` helper is retired because it could create persistent/headed browsers and fixed CDP ports; use the Chrome plugin or an explicitly isolated, Nix-managed runner instead. The broader Homebrew dev/infra stack (mariadb, nginx, supabase, stripe, tailscale, go, rust, …) is **not an agent-env dep and is out of scope here**.

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

## Memory Change Fast Path

Claude's self-learning memory is the harness-native auto-memory at `~/.claude/projects/<project>/memory/` (canonical). It is NOT Nix-managed: it is mutated only through the `self-learn` skill, which writes one fact per file plus a one-line `MEMORY.md` pointer and reads back to verify. Claude injects its index natively. Codex receives the same 200-line/25-KiB bounded pointer index through four Nix-managed SessionStart hook chunks (each below Codex's per-hook output limit), then opens only task-relevant topic files. Do not hand-edit memory from Nix activation, and do not route shared writes into `~/.codex/memories`; Codex native memory generation/use is enabled independently; this does not migrate or replace the shared Claude memory store. The hook is projected at `/etc/codex/hooks.json`, Codex's managed system layer, rather than user hook state. Therefore no mutable trust hash or pre-approval bypass is required.

## Codex Hook Changes

See [Codex native hook policy](codex-hooks-policy.md) for the retained registry,
exact-hash archives, activation-order safety gate and synthetic validation. Do not
copy Claude hook registries wholesale or change hook trust state. Preserve the
synchronous safety guard until the replacement system registry is live.

## Downstream Promotion

`/private/etc/nix-darwin` is the deployment root. Its `flake.lock` is the one
input graph consumed by a system switch. The root itself is not represented in
that lock, so a lock file alone cannot make a dirty deployment root reproducible.

Do not build or activate from a development checkout. Make edits in a dedicated
Git worktree, update an input explicitly there, validate both Darwin hosts, then
commit and fast-forward the live checkout. The `apply` entry point is deliberately
fail-closed: it rejects a dirty or untracked deployment root, disables dirty Nix
inputs, never updates `flake.lock`, and verifies `/run/current-system` after the
switch.

The live deployment checkout may be owned by `root:wheel` to prevent ordinary
tools from editing it. `apply` performs its cleanliness read with optional Git
locks disabled, so a read-only clean checkout remains deployable. Promote only a
reviewed fast-forward commit with `sudo git -C /private/etc/nix-darwin ...`; make
all source edits in a separate user-owned clone or worktree.

```text
feature worktree -> explicit lock update -> host builds -> commit/review
  -> fast-forward clean /private/etc/nix-darwin -> ./apply -> live readback
```

Use an immutable Git input for the shared upstream. Do not set `upstreamPath`
for a deployed profile: it would turn Claude skill files into out-of-store links
to a mutable checkout and bypass the lock.

Migrations are an explicit, versioned source change. Run them in the feature
worktree, review and commit their result, rather than letting `apply` mutate the
live deployment root.

If the goal is only to inspect projected files, build the locked source first and
inspect the store output instead of switching.

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
- Claude memory is the harness-native store under `~/.claude/projects/<project>/memory/` (mutated via the `self-learn` skill); do not route Claude writes into `~/.codex/memories`.
- Do not use `nix flake update` without an input name unless the task is dependency refresh.
- Do not run `nix flake update`, a migration, or `darwin-rebuild switch` from a dirty deployment root.
- Do not use familiarity or DX as a reason to add another config boundary.
- Keep local path assumptions in the downstream launcher layer; shared modules should express the abstract contract.
