#!/bin/sh
# wip-crawl 定期実行ラッパー（launchd から呼ぶ）。
# lock で多重起動を防ぎ、headless の Claude Code に /wip-crawl を実行させ、ログを残す。
# 初回は launchd を有効化せず、手動で `sh ~/.claude/skills/wip-crawl/run.sh` を監督実行して挙動確認すること。
set -eu

CACHE="$HOME/.claude/.cache/wip-crawl"
mkdir -p "$CACHE"
LOG="$CACHE/run.log"
LOCK="$CACHE/.lock"

# 同時実行ロック（前回が走行中なら今回はスキップ）
if [ -e "$LOCK" ]; then
  echo "$(date '+%F %T') locked, skip" >> "$LOG"
  exit 0
fi
trap 'rm -f "$LOCK"' EXIT INT TERM
: > "$LOCK"

export LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8
# launchd の最小 PATH では nix/claude/node/cosense-fetch が見えないので明示注入
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER}/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# `claude` は対話シェルでは alias(env CC_OPEN_TAB=1 cc=新タブ起動)に化けるが、#!/bin/sh では alias は効かず
# 実体バイナリに解決される。確実性のため per-user profile の実体パスを直指定する(nix世代更新でも安定)。
CLAUDE_BIN="/etc/profiles/per-user/${USER}/bin/claude"
[ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="$(command -v claude || true)"

echo "$(date '+%F %T') start (claude=$CLAUDE_BIN)" >> "$LOG"
# autonomous 書き込みのため skip-permissions。灰色[( ]は可逆・digest と再フェッチ検証は skill 側で担保。
"$CLAUDE_BIN" -p "/wip-crawl" --dangerously-skip-permissions >> "$LOG" 2>&1 || echo "$(date '+%F %T') claude exited $?" >> "$LOG"
echo "$(date '+%F %T') done" >> "$LOG"
