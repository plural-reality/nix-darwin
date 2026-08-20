#!/bin/sh
# gtd-external — Apple カレンダー / リマインダーを盤に載る形へ写す。
#
#   gtd-external.sh [日数] > external.json
#
# 出力: {"<升目の名前>": [{"raw": "📅2026/08/20 09:00 …", "detail": "…"}]}
# 升目の名前だけがこの層の設定。描画側は名前を知らず、渡された升目へ並べるだけ。
#
# 書き込みはしない。Scrapbox のカードと違い正本がここには無いので、盤の上では動かせない。
set -eu

DAYS="${1:-21}"
SCHEDULED_LANE="Scheduled"   # 時間で発火するもの
TRIGGERED_LANE="Triggered"   # 場所で発火するもの

# 予定が入るカレンダー。ルーティーンは習慣ブロック(睡眠・食事)なので終日予定だけ拾う
# ＝ゴミ収集のような「その日やること」は入り、毎日の習慣は入らない。
APPOINTMENTS='["Taka の予定","takagi@plural-reality.com","Shunsuke Takagi (General)","Business "]'
DAY_LEVEL='["ルーティーン"]'
LISTS='["Everything","📍場所","多元タスク","ある場所に居る時にやること"]'

start=$(date -u +%Y-%m-%dT00:00:00Z)
end=$(date -u -v+"${DAYS}"d +%Y-%m-%dT00:00:00Z)

snap=$(jq -nc --arg s "$start" --arg e "$end" \
  --argjson a "$APPOINTMENTS" --argjson d "$DAY_LEVEL" --argjson l "$LISTS" \
  '{rangeStart:$s, rangeEnd:$e,
    calendars:{names:($a+$d), ids:[]},
    reminderLists:{names:$l, ids:[]},
    includeCompleted:false, dueBefore:$e}' | evkit snapshot)

printf '%s' "$snap" | jq -c \
  --arg sched "$SCHEDULED_LANE" --arg trig "$TRIGGERED_LANE" --argjson appt "$APPOINTMENTS" '
  def jst: (. // "") | if . == "" then "" else
    (fromdate + 32400) | strftime("%Y/%m/%d %H:%M") end;
  def day: (. // "") | if . == "" then "" else
    (fromdate + 32400) | strftime("%Y/%m/%d") end;

  ((.events // []) | map(select((.calendar.name | IN($appt[])) or .allDay))
    | map({ raw: ("📅" + (if .allDay then (.start | day) else (.start | jst) end) + " " + .title),
            detail: ((.calendar.name // "?") + (if .location then "\n" + .location else "" end)) })) as $ev
  | ((.reminders // []) | map(select((.locationAlerts // []) | length == 0))
    | map(select(.due != null))
    | map({ raw: ("⏰" + (.due | jst) + " " + .title),
            detail: ("リマインダー / " + (.list.name // "?")) })) as $rd
  | ((.reminders // []) | map(select((.locationAlerts // []) | length > 0))
    | map({ raw: ("📍" + .title),
            detail: ("場所リマインダー / " + (.list.name // "?") + "\n"
                     + ((.locationAlerts // []) | map(.title // "場所") | join(", "))) })) as $rl
  | { ($sched): ($ev + $rd), ($trig): $rl }'
