#!/bin/bash
# daily-report-capture.sh
# SessionEnd / PreCompact hook(async)から呼ばれる、daily-report の「収集」段。
# その日の lifelog を決定的に gather して pending に保存するだけ。
# 分類・要約・書込(LLM判断)は次セッションの人間起動に委ねる(daily-report スキル本来の設計)。
# pending は最適化であって必須依存ではない: 無くても daily-report は手動で完全に動作する。
set -euo pipefail

# session-summary.sh が呼ぶ要約用 claude(CLAUDE_DAILY_SUMMARY=1)の SessionEnd では gather しない(再帰防止)。
[ "${CLAUDE_DAILY_SUMMARY:-}" = "1" ] && exit 0

CACHE="$HOME/.claude/.cache/daily-report"
DATE="$(TZ=Asia/Tokyo date +%Y-%m-%d)"   # lifelog.py の _today()(JST)に揃える
PENDING="$CACHE/$DATE.json"
LOCKDIR="$CACHE/.lock.d"
FRESH=1800                                # 直近30分に gather 済みなら再取得しない(clear/compact 連発の無駄打ち防止)

mkdir -p "$CACHE"

# 二重起動防止: mkdir は atomic(macOS に flock が無いため採用)。取れなければ別プロセスが収集中 → 退避。
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

# 鮮度ガード: pending が十分新しければスキップ
if [ -f "$PENDING" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$PENDING") ))
  [ "$age" -lt "$FRESH" ] && exit 0
fi

# gather(best-effort)。warn は stderr に出るので捨てる。atomic(tmp→mv)で差し替え。
if python3 "$HOME/.claude/scripts/lifelog.py" gather "$DATE" > "$PENDING.tmp" 2>/dev/null; then
  mv "$PENDING.tmp" "$PENDING"
  rm -f "$PENDING.reminded"               # 内容が更新されたので次セッションでの再通知を許可
else
  rm -f "$PENDING.tmp"
fi
