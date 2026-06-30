#!/usr/bin/env bash
# last-session-link.sh — SessionStart hook(matcher: clear)。
# /clear・/new で新セッションを始めたとき、直前まで作業していたセッションの記録先
# Scrapbox 日付ページを、新セッションの Claude に additionalContext として渡す
# (ユーザーが尋ねたら/冒頭でクリック可能リンクとして提示できるように)。
#
# 抽象:  f(stdin: SessionStart JSON) -> stdout: (additionalContext JSON | ∅)
#        daily-flush.py が書く last-saved.json(記録先 URL の唯一の機械可読ソース)を読むだけの
#        read-only な純粋フィルタ。その日の全セッションは同じ日付ページに集約されるので、
#        ここで出す URL は race-free(直前の要約がまだ flush 中でも、ページ自体は同じ)。
#
# 無音条件: last-saved.json が無い / それが今日の分でない(日跨ぎ) / 不正 JSON → 何も出さず exit 0。
#   → 記録が一件も無ければ静かに何も言わない。冪等で副作用なし。
#
# 注意:  SessionStart hook の stdout/additionalContext は「Claude のコンテキスト」に入るだけで
#        ユーザー画面には直接出ない。ユーザーへの確実な可視通知は session-summary.sh の
#        デスクトップ通知(terminal-notifier)が担当する。本スクリプトは in-session の
#        クリック可能リンク提示(Claude 経由)を担う、相補的な経路。
set -uo pipefail

readonly LAST="$HOME/.claude/.cache/daily-report/last-saved.json"
readonly DATE="$(TZ=Asia/Tokyo date +%Y-%m-%d)"

cat >/dev/null 2>&1 || true   # SessionStart JSON(本スクリプトは使わない)を読み捨てる

# ガード節を && 連鎖で式化。1 つでも偽なら無音で抜ける。
{ [ -f "$LAST" ] && [ "$(jq -r '.date // empty' "$LAST" 2>/dev/null)" = "$DATE" ]; } || exit 0

readonly urls="$(jq -r '.pages[]? | "・\(.project): \(.url)"' "$LAST" 2>/dev/null || true)"
[ -n "$urls" ] || exit 0

CTX="📝 直前のセッションの作業記録は、次の Scrapbox 日付ページに自動反映されています:
${urls}
ユーザーが「前回どこに保存した?」「日報」「記録どこ」等を尋ねた場合、または会話の冒頭で軽く案内する価値がある場合に、この Scrapbox リンクをそのまま提示してください。今のタスクと無関係なら一切言及しないでください。" \
  python3 -c "import json,os;print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':os.environ['CTX']}},ensure_ascii=False))" 2>/dev/null || true

exit 0
