#!/bin/bash
# Skill usage telemetry: PreToolUse hook (matcher: Skill).
# Records use_count and last_used_at to .meta.json in the skill directory.
# Fail-open: always exit 0.

set -uo pipefail

INPUT=$(cat)
SKILL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // .tool_input.name // empty' 2>/dev/null)
[[ -z "$SKILL_NAME" ]] && exit 0

# Search across all skill roots
for ROOT in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
  SKILL_DIR="$ROOT/$SKILL_NAME"
  [[ -d "$SKILL_DIR" ]] || continue
  
  META="$SKILL_DIR/.meta.json"
  NOW=$(date +%s)
  
  if [[ -f "$META" ]]; then
    COUNT=$(jq '.use_count // 0' "$META" 2>/dev/null || echo 0)
    NEW_COUNT=$((COUNT + 1))
    printf '{"use_count":%d,"last_used_at":%d}' "$NEW_COUNT" "$NOW" > "${META}.tmp.$$"
    mv "${META}.tmp.$$" "$META"
  else
    printf '{"use_count":1,"last_used_at":%d}' "$NOW" > "$META" 2>/dev/null || true
  fi
done

exit 0
