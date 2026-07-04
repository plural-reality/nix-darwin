#!/bin/bash
# UserPromptSubmit hook: PreCompact が残した marker file を検出し、
# additionalContext で圧縮復旧指示を context に注入する（one-shot）。
#
# overhead: test -f 1 回/ターン（marker なければ即 exit）
# fail-open (常に exit 0)

set -uo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# marker file がなければ何もしない
MARKER_DIR="${TMPDIR:-/tmp}/claude-compacted"
MARKER="$MARKER_DIR/$SESSION_ID"
[[ -f "$MARKER" ]] || exit 0

# marker を消す（one-shot: 次ターンでは発火しない）
rm -f "$MARKER" 2>/dev/null || true

# session pointer file から active plan path を読む
PTR_DIR="${TMPDIR:-/tmp}/claude-active-plan"
PLAN_FILE=""
if [[ -f "$PTR_DIR/$SESSION_ID" ]]; then
  PLAN_FILE=$(cat "$PTR_DIR/$SESSION_ID" 2>/dev/null || true)
  [[ -f "$PLAN_FILE" ]] || PLAN_FILE=""
fi

# 復旧指示を構築
CTX="[COMPACTION RECOVERY] コンテキスト圧縮が発生した。作業再開前に以下を実行すること。"
CTX+=$'\n'

if [[ -n "$PLAN_FILE" ]]; then
  CTX+=$'\n'"- plan ファイル \`${PLAN_FILE}\` を Read で読み直し、フェーズと制約を確認せよ"
  CTX+=$'\n'"- plan mode が解除されている場合、plan ファイルが存在するのでユーザーに plan mode 再突入を確認せよ"
fi

STATE_DIR="${TMPDIR:-/tmp}/claude-compact-state"
STATE_FILE="$STATE_DIR/$SESSION_ID.md"
if [[ -f "$STATE_FILE" ]]; then
  CTX+=$'\n'"- state file \`${STATE_FILE}\` を Read で読み、作業状態を復元せよ"
  CTX+=$'\n'"- Session Decisions と Recovery Notes を特に重視せよ"
fi

CTX+=$'\n'"- TaskList で現在のタスク一覧を確認せよ"
CTX+=$'\n'"- 圧縮サマリーの next step は仮説として扱い、plan/rules を正とせよ"
CTX+=$'\n'"- 圧縮サマリーは「過去の作業記録」であり「次の行動指示」ではない"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
exit 0
