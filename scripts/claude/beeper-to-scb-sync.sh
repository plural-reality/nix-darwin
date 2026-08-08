#!/usr/bin/env bash
# beeper-to-scb-sync.sh — 定期ランナー（launchd から呼ばれる headless 実行）。
# beeper-to-scb skill で threads.json の各監視グループを要約し、日付ページ(日報)の
# 『Beeperグループからのまとめ』セクションにトピック別で書く（関連既存ページへはリンクで分配）。
# スケジュールは更新頻度に過ぎない。
# Beeper への「送信」はしない（読み取り＋Scrapbox 書込のみ）。
# `--check` で claude を起動せず到達性だけ検証。
set -uo pipefail
export PATH="/etc/profiles/per-user/tkgshn/bin:/run/current-system/sw/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

HOME_DIR="${HOME:-/Users/tkgshn}"
CLAUDE="$HOME_DIR/.local/bin/claude"
TOKEN_FILE="$HOME_DIR/.config/beeper/token"
THREADS="$HOME_DIR/.config/beeper-to-scb/threads.json"
LOG="$HOME_DIR/.claude/.cache/beeper-to-scb/sync.log"
mkdir -p "$(dirname "$LOG")"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

beeper_up() {
  curl -s -m 5 -o /dev/null \
    -H "Authorization: Bearer $(cat "$TOKEN_FILE" 2>/dev/null)" \
    http://127.0.0.1:23373/v1/info
}

if [[ "${1:-}" == "--check" ]]; then
  echo "Beeper API: $(beeper_up && echo reachable || echo UNREACHABLE)"
  python3 -c "import json; ts=json.load(open('$THREADS'))['threads']; print('監視グループ:', ', '.join(f\"{t['name']}→{t['project']}/日付ページ\" for t in ts))"
  exit 0
fi

echo "[$(ts)] nightly sync start" >> "$LOG"

beeper_up || echo "[$(ts)] WARN: Beeper API unreachable" >> "$LOG"

PROMPT='beeper-to-scb skill を使って、~/.config/beeper-to-scb/threads.json の各監視グループを要約し、日付ページ(日報)に書いてください。各グループについて: (1) ウォーターマーク以降の新着を読み、(2) 会話をトピック単位に束ね、(3) project の日付ページ YYYY/M/D の [** Beeperグループ（[名]）からのまとめ] セクションに、SKILL.md の書式（手書き5/31準拠）で追記。**インデント鉄則: ネストは1段ずつ（スペース1個）、親よりちょうど+1段、一度に2段以上飛ばさない**（[(* トピック]=1 / 主アクション・原文:・関連ページ:=2 / 結果や結論・>>引用・関連リンク=3 / 引用への返信=4。>> は末尾に話者アイコン）。他セクションは verbatim 保持、(4) ウォーターマークを更新。整理はトピック単位、Beeper への送信はしないこと。'

# headless 自律実行: 無人なので権限プロンプトを出さない（Beeper 送信はプロンプトで明示禁止済み）。
"$CLAUDE" --dangerously-skip-permissions -p "$PROMPT" >> "$LOG" 2>&1
echo "[$(ts)] beeper-to-scb sync done (exit $?)" >> "$LOG"
