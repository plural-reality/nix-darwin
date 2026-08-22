#!/bin/bash
# Session lineage tracking: record compression events per session.
# Called by PreCompact (write) and UserPromptSubmit-restore (read).
# Storage: ~/.claude/.session-lineage/<session_id>.json

set -uo pipefail

readonly LINEAGE_DIR="$HOME/.claude/.session-lineage"

mode="${1:-record}"
INPUT="${2:-}"

[[ -z "$INPUT" ]] && INPUT=$(cat 2>/dev/null || true)

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

mkdir -p "$LINEAGE_DIR" 2>/dev/null || true
FILE="$LINEAGE_DIR/$SESSION_ID.json"

case "$mode" in
  record)
    # Increment compaction generation
    if [[ -f "$FILE" ]]; then
      jq --argjson now "$(date +%s)" \
        '.compactions += [{generation: (.compactions | length) + 1, at: $now, msg_count: (.compactions[-1].msg_count // 0)}]' \
        "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
    else
      printf '{"compactions":[{"generation":1,"at":%d,"msg_count":0}]}' "$(date +%s)" > "$FILE"
    fi
    ;;
  read)
    [[ -f "$FILE" ]] || exit 0
    GEN=$(jq '.compactions | length' "$FILE" 2>/dev/null || echo 0)
    [[ "$GEN" -lt 1 ]] && exit 0
    LAST_AT=$(jq -r '.compactions[-1].at // empty' "$FILE" 2>/dev/null || true)
    echo "compact_generation=$GEN last_compaction_at=$LAST_AT"
    ;;
esac
exit 0
