#!/bin/sh
# gtd-fetch — 看板ページと、そこに並ぶカードのリンク先本文をまとめて1つの JSON にする。
# ここが唯一の IO 境界。描画側(gtd-canvas.mjs)はこの JSON だけを見る純粋関数のままにする。
#
#   gtd-fetch.sh "ToDoカンバン" plural-reality | gtd-canvas.mjs --project plural-reality > out.html
#
# 出力: {"lines": ["…"], "pages": {"<カードのタイトル>": "<本文(タイトル行を除く)>"}}
set -eu

PAGE="${1:?usage: gtd-fetch.sh <page> [project]}"
PROJECT="${2:-plural-reality}"
SID="$(jq -r '.env.SCRAPBOX_SID // empty' "$HOME/.claude/settings.local.json" 2>/dev/null || true)"

board=$(cosense-fetch -r "$PAGE" -p "$PROJECT")

# カード = 字下げされたページリンク。階層の深さは問わない(升目の入れ子は任意に深くなれる)。
# `[** 名前]` などの装飾記法・`.icon`・外部 URL はページリンクではないので除く。
titles=$(printf '%s' "$board" | jq -r '
  .lines[].text
  | select(test("^[ \t]+\\[.+\\]$"))
  | sub("^[ \t]+"; "") | .[1:-1]
  | select(test("^(?:[*/\\-_!\"#%&]+\\s|https?:)|\\.icon$") | not)')

# 1件ずつ引いて {title: body} に畳む。存在しないページは空文字になる。
pages=$(printf '%s\n' "$titles" | while IFS= read -r t; do
  [ -n "$t" ] || continue
  enc=$(jq -rn --arg t "$t" '$t|@uri')
  curl -s --max-time 10 -H "Cookie: connect.sid=${SID}" \
    "https://scrapbox.io/api/pages/${PROJECT}/${enc}" |
    jq -c --arg t "$t" '{key: $t, value: ([.lines[]?.text][1:] | join("\n"))}'
done | jq -sc 'from_entries')

# Apple カレンダー/リマインダー。取れなくても盤は成立するので、失敗は空として畳む。
external=$("${0%/*}/gtd-external.sh" 2>/dev/null || printf '{}')

jq -nc --argjson b "$board" --argjson p "${pages:-{\}}" --argjson x "${external:-{\}}" \
  '{lines: [$b.lines[].text], pages: $p, external: $x}'
