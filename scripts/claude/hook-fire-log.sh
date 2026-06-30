#!/bin/bash
# hook-fire-log.sh — hook 発火の生証跡ロガー(検証用・可逆)
# 目的: 「その hook イベントが本当に発火したか」をプロセス内部に依存せず外形的に証明する。
# 使い方: stdin に Claude Code の hook イベントJSON、$1 にイベント名ラベルを渡す。
#   例) /bin/bash ~/.claude/scripts/hook-fire-log.sh SessionEnd
# 出力: ~/.claude/.cache/daily-report/hook-fire.log に [JST時刻]\t[イベント]\t[生JSON] を1行追記するだけ。
# 既存の capture/remind には一切干渉しない。不要になれば settings.local.json から該当 hook を消すだけで撤去できる。
set -euo pipefail

LOG="$HOME/.claude/.cache/daily-report/hook-fire.log"
mkdir -p "$(dirname "$LOG")"

TS="$(TZ=Asia/Tokyo date +%Y-%m-%dT%H:%M:%S%z)"
EVT="${1:-?}"
PAYLOAD="$(cat 2>/dev/null || true)"   # hook イベントJSON(reason/source/session_id 等を含む)。空でも可。

printf '%s\t%s\t%s\n' "$TS" "$EVT" "$PAYLOAD" >> "$LOG"
