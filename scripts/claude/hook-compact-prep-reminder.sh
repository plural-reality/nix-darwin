#!/bin/bash
# UserPromptSubmit hook: statusline が書いた compact-warn marker を検出し、
# additionalContext で compact-prep 実行を促す（one-shot）。
#
# フロー:
#   statusline-command.sh が ctx >= 閾値 で warn marker 書込
#   → 本 hook が検出 → additionalContext 注入 → warn marker 削除 + warned marker 作成
#   → PreCompact hook (hook-compaction-recovery.sh) が warned marker 削除（cooldown リセット）
#
# overhead: test -f 1 回/ターン（marker なければ即 exit）
# fail-open (常に exit 0)

set -uo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# warn marker がなければ何もしない
WARN_DIR="${TMPDIR:-/tmp}/claude-compact-warn"
WARN_MARKER="$WARN_DIR/$SESSION_ID"
[[ -f "$WARN_MARKER" ]] || exit 0

# marker から使用率を読み取る
CTX_PCT=$(cat "$WARN_MARKER" 2>/dev/null)
CTX_PCT=${CTX_PCT:-"?"}

# warn marker を消す（one-shot）
rm -f "$WARN_MARKER" 2>/dev/null || true

# cooldown marker を作成（statusline が再度 warn marker を書くのを防止）
WARNED_DIR="${TMPDIR:-/tmp}/claude-compact-warned"
mkdir -p "$WARNED_DIR" 2>/dev/null || true
printf '%s\n' "$(date +%s)" > "$WARNED_DIR/$SESSION_ID" 2>/dev/null || true

CTX="[COMPACT PREP REMINDER] context 使用率が ${CTX_PCT}% に達した。"
CTX+=$'\n'"- 作業区切りでユーザーに \`/compact-prep\` の実行を提案せよ。"
CTX+=$'\n'"- \`/compact-prep\` 実行後、ユーザーに \`/compact\` 実行を案内せよ。"
CTX+=$'\n'"- scope 縮小や別セッション化ではなく、圧縮前 state 保存で対処せよ。"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
exit 0
