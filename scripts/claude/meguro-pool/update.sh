#!/usr/bin/env bash
# update.sh — 目黒区民プール 月次洗い替えランナー（launchd から呼ばれる headless 実行）。
# meguro-pool-update skill が公式PDFを取得→解釈→schedule.json→apply_schedule.swift(EventKit洗い替え)。
# 権限は最小（--allowedTools 限定。Beeper のような skip-permissions は使わない）。
# `--check` で claude を起動せず到達性だけ確認。
set -uo pipefail
export PATH="/etc/profiles/per-user/tkgshn/bin:/run/current-system/sw/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

HOME_DIR="${HOME:-/Users/tkgshn}"
CLAUDE="$HOME_DIR/.local/bin/claude"
APPLIER="$HOME_DIR/.claude/scripts/calendar/apply.swift"
LOG="$HOME_DIR/.claude/.cache/meguro-pool/update.log"
mkdir -p "$(dirname "$LOG")"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

if [[ "${1:-}" == "--check" ]]; then
  echo "claude:    $([[ -x "$CLAUDE" ]] && echo OK || echo MISSING) ($CLAUDE)"
  echo "applier:   $([[ -f "$APPLIER" ]] && echo OK || echo MISSING) ($APPLIER)"
  echo "pdftotext: $(command -v pdftotext || echo MISSING)"
  echo "swift:     $(command -v swift || echo MISSING)"
  echo "index:     $(curl -s -m 8 -o /dev/null -w '%{http_code}' https://www.city.meguro.tokyo.jp/sports/bunkasports/sports/indoorpool_nittei.html)"
  exit 0
fi

echo "[$(ts)] meguro-pool update start" >> "$LOG"

PROMPT='meguro-pool-update skill を実行して。目黒区民センター体育館プールの当月(取得できれば翌月も)個人利用スケジュールを公式PDF(indoorpool_nittei.html から center-jpn PDF を解決)から取得し、「往復コース(ラップ用3・4)が使える時間だけ」のルールで汎用イベントJSON(mode=replace-month, defaultLocationつき)を作り、`swift ~/.claude/scripts/calendar/apply.swift` (apple-calendar の窓口)で iCloudカレンダー「目黒区民プール」を当月洗い替えしてください。夏季(7-9月)は屋外50mも追加。当月PDFが未掲載なら何もせず終了。'

"$CLAUDE" -p "$PROMPT" \
  --allowedTools "Bash(curl:*)" "Bash(pdftotext:*)" "Bash(swift:*)" "Bash(jq:*)" "Bash(date:*)" "Bash(grep:*)" "Bash(sed:*)" "Bash(mkdir:*)" "Read" "Write" "WebFetch" \
  >> "$LOG" 2>&1
echo "[$(ts)] meguro-pool update done (exit $?)" >> "$LOG"
