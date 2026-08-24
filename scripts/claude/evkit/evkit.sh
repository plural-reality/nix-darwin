#!/usr/bin/env bash
# evkit — Apple カレンダー/リマインダーを読書きする唯一の client。
#
#   f(spec JSON on stdin) -> result JSON on stdout
#
# この client 自身は EventKit を触らないので、**TCC 権限を一切必要としない**。
# 実際の副作用は MacBook Air の LaunchAgent(gui/501, Aqua)で動く署名済み evkitd が起こす。
# よって SSH 越し・tmux 内・Claude Code が何度更新されようと、権限は失われない。
#
# transport は自明に縮退する:
#   - Air(ソケットがローカルに在る)     → unix domain socket に直結
#   - Mac mini など(ソケットが無い)      → ssh で Air に渡し、向こう側で同じソケットに繋ぐ
#     (ssh 越しの nc は TCC 権限を要らないので、sshd の Background ドメイン問題を踏まない)
#
# usage:
#   evkit status                                  # 許可状態を見る
#   evkit seed                                    # 初回の許可ダイアログを出す(Air の画面で承認)
#   evkit calendar.catalog                        # ID付きカレンダー台帳を読む
#   evkit calendar.delete       < spec.json       # 空の指定カレンダーをIDで削除
#   evkit snapshot            < snapshot.json     # Calendar + Reminders を一括読取
#   evkit calendar            < events.json
#   evkit reminders.recurring < spec.json
#   evkit reminders.geofence  < spec.json
#   evkit reminders.section   < spec.json     # リマインダーの「セクション」(EventKit に無い)
#   evkit reminders.complete  < spec.json     # 完了状態の変更
set -euo pipefail

readonly SOCK="/Users/tkgshn/Library/Application Support/EventKitBridge/evkitd.sock"
readonly AIR_HOST="tkgshn-macbook-air"

op="${1:-status}"

case "$op" in
  status | seed)
    request="$(printf '{"op":"%s"}' "$op")"
    ;;
  calendar.catalog)
    request='{"op":"calendar.catalog"}'
    ;;
  snapshot | calendar | calendar.delete | reminders.recurring | reminders.geofence | reminders.section | reminders.complete)
    # stdin の spec をそのまま包む。spec の schema は各 skill / 各 .swift が canonical。
    request="$(jq -c --arg op "$op" '{op: $op, spec: .}')"
    ;;
  *)
    printf 'evkit: unknown op %s\n' "$op" >&2
    printf 'ops: status seed calendar.catalog calendar.delete snapshot calendar reminders.recurring reminders.geofence reminders.section reminders.complete\n' >&2
    exit 64
    ;;
esac

# 1接続 = 改行終端の JSON 1行。macOS の nc には BSD の -N(EOF で half-close)が無いので、
# 「stdin を閉じれば相手が読み終える」に依存せず、改行で request の終端を示す。
if [ -S "$SOCK" ]; then
  printf '%s\n' "$request" | nc -U "$SOCK"
elif [ "$(hostname -s)" = "tkgshn-MacBook-Air" ]; then
  printf 'evkit: ここは Air なのにソケットが無い。LaunchAgent が落ちている。\n' >&2
  printf '  launchctl print gui/%s/org.nix-community.home.evkitd\n' "$(id -u)" >&2
  exit 69
else
  printf '%s\n' "$request" | ssh -o ConnectTimeout=8 "$AIR_HOST" "nc -U '$SOCK'"
fi
