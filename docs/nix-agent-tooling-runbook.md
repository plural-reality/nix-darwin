# Nix Agent Tooling Runbook

Read this before changing Nix/Home Manager, Claude/Codex prompts, skills, or shared agent scripts.

## Source Of Truth

- Shared skills live at `prompt/claude-code/skills/<name>/`.
- Shared scripts live at `scripts/` and are wired by `modules/shared-scripts.nix`.
- Agent prompt/config projection is owned by `modules/claude-code.nix`.
- Live files under `~/.claude/*` and `~/.codex/*` are generated outputs.
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
