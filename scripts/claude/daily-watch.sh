#!/usr/bin/env bash
set -euo pipefail

readonly TARGET='T4011503006669'
readonly WATCH_ID='corp-invoice-registration'
readonly MARKER='[watch:corp-invoice-registration]'
readonly LIST='多元タスク'
readonly TITLE='登録番号を請求書・freeeへ反映する'
readonly DIFF_PAGE='https://www.invoice-kohyo.nta.go.jp/download/sabun/'
readonly STATE="${CODEX_HOME:-$HOME/.codex}/automations/automation-2/state/watch-state.json"

definitions() {
  corporate="$(cosense-fetch '自動監視（多元現実）' -p plural-reality -h 1)"
  personal="$(cosense-fetch '自動監視（個人）' -p tkgshn-private -h 1)"
  printf '%s\n%s\n' "$corporate" "$personal" | jq -Rs \
    --arg id "$WATCH_ID" --arg marker "$MARKER" --arg list "$LIST" --arg title "$TITLE" '
      {ok: (contains($id) and contains($marker) and contains($list) and contains($title)),
       corporate: (contains("corp-gmo-address") and contains("corp-invoice-registration")),
       personal: contains("personal-sounkyo-forecast")}'
}

invoice() {
  html="$(curl -fsSL "$DIFF_PAGE")"
  manager="$(printf '%s' "$html" | rg -o -m1 "doDownload\\('[0-9]+','01'\\)" | sed -E "s/.*\\('([0-9]+)'.*/\\1/")"
  [ -n "$manager" ] || { printf '{"ok":false,"status":"一時的に取得できません","reason":"公式差分の管理番号を取得できません"}\n'; return 1; }
  url="https://www.invoice-kohyo.nta.go.jp/download/sabun/dlfile?dlFilKanriNo=${manager}&type=01"
  row="$(curl -fsSL "$url" | bsdtar -xOf - | rg ",\"${TARGET}\"," || true)"
  fingerprint="$(printf '%s' "$row" | sha256sum | cut -d' ' -f1)"
  jq -cn --arg manager "$manager" --arg url "$url" --arg target "$TARGET" \
    --arg fingerprint "$fingerprint" --arg row "$row" \
    '{ok:true,status:"取得済み",managerNo:$manager,source:$url,target:$target,
      present:($row != ""),fingerprint:$fingerprint}'
}

ensure_invoice_reminder() {
  jq -cn --arg listTitle "$LIST" --arg title "$TITLE" --arg marker "$MARKER" \
    '{listTitle:$listTitle,title:$title,marker:$marker}' | evkit reminders.ensure
}

write_state() {
  local now="$1" invoice_json="$2" reminder_json="$3"
  local directory draft
  directory="$(dirname "$STATE")"
  draft="${STATE}.new.$$"
  mkdir -p "$directory"
  [ -f "$STATE" ] || printf '{"version":1,"watches":{}}\n' > "$STATE"
  jq --arg now "$now" --arg id "$WATCH_ID" --arg marker "$MARKER" \
    --arg title "$TITLE" --arg list "$LIST" \
    --argjson invoice "$invoice_json" --argjson reminder "$reminder_json" '
      .version = 2
      | .lastRunAt = $now
      | .watches[$id] = ((.watches[$id] // {}) + {
          status:"変化あり", state:"変化あり", lastCheckedAt:$now,
          fingerprint:$invoice.fingerprint,
          observation:{present:$invoice.present,target:$invoice.target,managerNo:$invoice.managerNo},
          marker:$marker,onChange:$title,list:$list,
          reminder:{id:$reminder.reminder.id,created:$reminder.created}
        } | del(.blockedReason))
      | .run = ((.run // {}) + {
          result:"change",
          blockedCount: ([((.run.blockedCount // 0) - 1), 0] | max),
          successCount: ((.run.successCount // 0) + 1),
          changes: ((.run.changes // 0) + 1),
          externalSideEffects:$reminder.created, sideEffects:$reminder.created,
          completedAt:$now, lastWatchAt:$now, lastChange:{id:$id,marker:$marker}
        })' "$STATE" > "$draft"
  chmod 0600 "$draft"
  mv -f "$draft" "$STATE"
}

run() {
  definition_json="$(definitions)"
  [ "$(jq -r .ok <<<"$definition_json")" = true ] || { printf '%s\n' "$definition_json"; return 1; }
  invoice_json="$(invoice)"
  chrome_status=0
  chrome_json="$(node "$HOME/.claude/scripts/gmo-watch.mjs")" || chrome_status=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$chrome_json"; then
    chrome_json='{"ok":false,"status":"一時的に取得できません","reason":"GMO監視adapterの応答を確認できませんでした。","source":"invalid-output"}'
    [ "$chrome_status" -ne 0 ] || chrome_status=78
  fi
  gmo_ok="$(jq -r 'if .ok == true then "true" else "false" end' <<<"$chrome_json")"
  gmo_blocked=false
  if [ "$chrome_status" -ne 0 ] || [ "$gmo_ok" != true ]; then
    gmo_blocked=true
  fi
  present="$(jq -r .present <<<"$invoice_json")"
  previous="$([ -f "$STATE" ] && jq -r --arg id "$WATCH_ID" '.watches[$id].fingerprint // ""' "$STATE" || true)"
  fingerprint="$(jq -r .fingerprint <<<"$invoice_json")"
  changed=false
  if [ "$present" = true ] && [ "$fingerprint" != "$previous" ]; then
    reminder_json="$(ensure_invoice_reminder)"
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    write_state "$now" "$invoice_json" "$reminder_json"
    changed=true
  else
    reminder_json='null'
  fi
  jq -cn --argjson definitions "$definition_json" --argjson invoice "$invoice_json" \
    --argjson chrome "$chrome_json" --argjson reminder "$reminder_json" \
    --argjson changed "$changed" --argjson blocked "$gmo_blocked" \
    '{ok:($definitions.ok and $invoice.ok and $chrome.ok and ($blocked|not)),blocked:$blocked,changed:$changed,definitions:$definitions,
      invoice:$invoice,gmo:$chrome,reminder:$reminder}'
  if [ "$gmo_blocked" = true ]; then
    [ "$chrome_status" -ne 0 ] || chrome_status=78
    return "$chrome_status"
  fi
}

case "${1:-run}" in
  definitions) definitions ;;
  invoice) invoice ;;
  gmo) node "$HOME/.claude/scripts/gmo-watch.mjs" ;;
  run) run ;;
  *) printf 'usage: daily-watch [definitions|invoice|gmo|run]\n' >&2; exit 64 ;;
esac
