#!/usr/bin/env bash
# skill-sync.sh — Bidirectional Claude Code skill sync checker
# SessionStart hook: detects local-only and upstream-only skills
# Exit 0 always (never block session startup)

set -euo pipefail

# --- Locate nix-darwin repo ---

find_nix_darwin_repo() {
  if [[ -n "${NIX_DARWIN_REPO:-}" ]] && [[ -d "$NIX_DARWIN_REPO/.git" ]]; then
    echo "$NIX_DARWIN_REPO"
    return 0
  fi
  local candidates=(
    "$HOME/Developer/plural-reality/nix-darwin"
    "/private/etc/nix-darwin"
    "$HOME/nix-darwin"
    "$HOME/.config/nix-darwin"
  )
  for dir in "${candidates[@]}"; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

REPO_DIR="$(find_nix_darwin_repo 2>/dev/null)" || exit 0
SKILLS_DIR="$REPO_DIR/prompt/claude-code/skills"
LOCAL_SKILLS="$HOME/.claude/skills"

[[ -d "$SKILLS_DIR" ]] || exit 0
[[ -d "$LOCAL_SKILLS" ]] || exit 0

# --- Patterns to ignore (personal / auto-generated) ---
is_personal_skill() {
  local name="$1"
  case "$name" in
    nanyo-*) return 0 ;;
    limitless-context) return 0 ;;
    pendant-context) return 0 ;;
    save-to-scrapbox) return 0 ;;
    beeper-send) return 0 ;;
    imessage-send) return 0 ;;
    daily-briefing) return 0 ;;
    browser-automation) return 0 ;;
    kabeuchi-coach) return 0 ;;
    frontend-design) return 0 ;;
    plural-reality-design-system) return 0 ;;
    lp-hero-video) return 0 ;;
    natural-writing) return 0 ;;
    fix) return 0 ;;
    nanyo-index) return 0 ;;
    keybindings-help) return 0 ;;
    simplify) return 0 ;;
    claude-developer-platform) return 0 ;;
  esac
  return 1
}

# --- Find local-only skills (candidates for publishing) ---
local_only=()
for dir in "$LOCAL_SKILLS"/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")

  # Skip symlinks (nix-managed)
  [[ -L "${dir%/}" ]] && continue

  # Skip personal/auto-generated skills
  is_personal_skill "$name" && continue

  # Must have SKILL.md
  [[ -f "$dir/SKILL.md" || -f "$dir/skill.md" ]] || continue

  # Not in upstream
  if [[ ! -d "$SKILLS_DIR/$name" ]]; then
    local_only+=("$name")
  fi
done

# --- Find upstream-only skills (need darwin-rebuild switch) ---
upstream_only=()
for dir in "$SKILLS_DIR"/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  if [[ ! -d "$LOCAL_SKILLS/$name" ]]; then
    upstream_only+=("$name")
  fi
done

# --- Report ---
MSG=""

if [[ ${#local_only[@]} -gt 0 ]]; then
  MSG="[skill-sync] チーム未共有のスキル: ${local_only[*]}"
  MSG="$MSG\n  → /publish-skill <name> で nix-darwin に PR 作成"
fi

if [[ ${#upstream_only[@]} -gt 0 ]]; then
  if [[ -n "$MSG" ]]; then MSG="$MSG\n"; fi
  MSG="${MSG}[skill-sync] upstream に新スキル: ${upstream_only[*]}"
  MSG="$MSG\n  → darwin-rebuild switch でデプロイ"
fi

if [[ -n "$MSG" ]]; then
  printf '%b\n' "$MSG"
fi

exit 0
