#!/bin/bash
# skill (stdin の無いコンテキスト) 用の session_id 取得。
# 正本 = Claude Code が子プロセスに渡す $CLAUDE_CODE_SESSION_ID env。
# hook の stdin JSON (.session_id) と同一値。取れなければ空で exit 1 →
# 呼び出し側 skill が Hard gate で停止する（推測名で state file を作らない、
# が compact-prep skill の設計意図）。
set -uo pipefail

[[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]] && { printf '%s\n' "$CLAUDE_CODE_SESSION_ID"; exit 0; }
exit 1
