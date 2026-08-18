#!/bin/sh
# todo-kanban-autoupdate 定期実行ラッパー(launchd から 3〜4h ごとに呼ぶ)。
# lock で多重起動を防ぎ、SID を自己修復し、headless の Claude Code に /todo-gap --autonomous を
# 実行させ、ログを残す。canonical ロジック = todo-gap-analysis skill + save-to-scrapbox の局所配置規約。
# この run.sh は lock+env+SID+claude の配線だけを担う。
# 初回は launchd を有効化せず、手動 `sh ~/.claude/skills/todo-gap-analysis/run.sh` で監督実行して確認する。
set -eu

CACHE="$HOME/.claude/.cache/todo-kanban-autoupdate"
mkdir -p "$CACHE"
LOG="$CACHE/run.log"
LOCK="$CACHE/.lock"

if [ -e "$LOCK" ]; then
  echo "$(date '+%F %T') locked, skip" >> "$LOG"
  exit 0
fi
trap 'rm -f "$LOCK"' EXIT INT TERM
: > "$LOCK"

export LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8
# launchd の最小 PATH では nix/claude/node/cosense-fetch/scrapbox-write が見えないので明示注入。
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER}/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# SID 自己修復: 静的 SID は定期失効し guest 落ちするので、ログイン済み Chrome から実行時に再生成し
# settings.local.json に注入 + この run の env へ export。失敗時は既存 env にフォールバック。
if FRESH=$("$HOME/.claude/scripts/scrapbox-sid-refresh.sh" 2>>"$LOG"); then
  export SCRAPBOX_SID="$FRESH"
else
  echo "$(date '+%F %T') SID refresh failed; fall back to settings env" >> "$LOG"
  [ -f "$HOME/.claude/settings.local.json" ] && \
    SCRAPBOX_SID=$(jq -r '.env.SCRAPBOX_SID // empty' "$HOME/.claude/settings.local.json" 2>/dev/null) && \
    export SCRAPBOX_SID
fi

# guest なら Scrapbox 書込は全滅するので、claude を起動せず早期終了(コスト無駄打ち回避)。
ME=$(curl -s --max-time 8 -H "Cookie: connect.sid=${SCRAPBOX_SID:-}" https://scrapbox.io/api/users/me 2>/dev/null || true)
case "$ME" in
  *'"isGuest":true'*|'') echo "$(date '+%F %T') guest/no-SID; abort (Chrome未ログイン/ロック?)" >> "$LOG"; exit 0 ;;
esac

CLAUDE_BIN="/etc/profiles/per-user/${USER}/bin/claude"
[ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="$(command -v claude || true)"

echo "$(date '+%F %T') start (claude=$CLAUDE_BIN)" >> "$LOG"
# autonomous 書き込みのため skip-permissions。finding は canonical task/project pageへ局所反映し、
# 横断 summary は daily page へ置く。2看板はindex移動が必要な時だけCAS付きreplaceする。
"$CLAUDE_BIN" -p "/todo-gap --autonomous : ToDoカンバンとプロジェクト看板(plural-reality)を分析し、save-to-scrapboxのGTD canonical contractに従ってfindingをcanonical task/project pageへ更新して。2看板に独立AIセクションやrun summaryを書かず、index移動が必要な場合だけ全体候補を--mode replace --verbatim --expect-sha256で更新し、直APIで再取得検証すること。" \
  --dangerously-skip-permissions >> "$LOG" 2>&1 || echo "$(date '+%F %T') claude exited $?" >> "$LOG"
echo "$(date '+%F %T') done" >> "$LOG"
