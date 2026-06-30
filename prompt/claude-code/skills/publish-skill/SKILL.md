---
name: publish-skill
description: >
  Publish a local Claude Code skill to the shared nix-darwin upstream.
  Use when: user says "publish skill", "share skill", "スキルを共有",
  "スキルをpublish", or when skill-sync.sh reports unpublished local skills.
---

# Publish Skill to nix-darwin

Copies a local `~/.claude/skills/<name>/` to `plural-reality/nix-darwin` and creates a PR.

## Procedure

When invoked as `/publish-skill <name>`:

### 1. Validate

```bash
# Check the skill exists locally
SKILL_NAME="<name>"  # from argument
LOCAL_DIR="$HOME/.claude/skills/$SKILL_NAME"

# Must exist and have SKILL.md
test -d "$LOCAL_DIR" || { echo "Error: $LOCAL_DIR not found"; exit 1; }
test -f "$LOCAL_DIR/SKILL.md" -o -f "$LOCAL_DIR/skill.md" || { echo "Error: No SKILL.md found"; exit 1; }
```

### 2. Find nix-darwin repo

Search in order:
1. `$NIX_DARWIN_REPO` (env var)
2. `~/Developer/plural-reality/nix-darwin`
3. `/private/etc/nix-darwin`
4. `~/nix-darwin`
5. `~/.config/nix-darwin`

If not found, clone it:
```bash
gh repo clone plural-reality/nix-darwin ~/Developer/plural-reality/nix-darwin
```

### 3. Create branch, copy, commit, push, PR

```bash
cd "$REPO_DIR"
git checkout main && git pull
git checkout -b "feat/skill-$SKILL_NAME"

# Copy skill directory
cp -r "$LOCAL_DIR" "$REPO_DIR/prompt/claude-code/skills/$SKILL_NAME"

# Commit
git add "prompt/claude-code/skills/$SKILL_NAME"
git commit -m "Add $SKILL_NAME skill"

# Push and create PR
git push -u origin "feat/skill-$SKILL_NAME"
gh pr create \
  --title "Add $SKILL_NAME skill" \
  --body "Auto-published from local ~/.claude/skills/$SKILL_NAME via /publish-skill"
```

### 4. Report

Print the PR URL. Remind user:
- After merge, team runs `darwin-rebuild switch` to deploy
- The skill will be auto-detected by `claude-code.nix`

## Important Notes

- **Do NOT publish personal skills** (nanyo-*, pendant-context, save-to-scrapbox, etc.)
- **Review SKILL.md** before publishing — remove machine-specific paths, secrets, personal config
- **Abstract if needed** — if the skill references a specific project (e.g., baisoku-survey), generalize it first
- The `SKILL.md` file supports `@[filename]` template expansion — referenced files must exist in `prompt/`
- Symlinked skills (already nix-managed) don't need publishing — they're already in upstream
