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
# CLI の exit 0 だけでは認証失敗・unknown command を判別できないため、最終結果も検証する。
RESULT="$CACHE/last-result.json"
if "$CLAUDE_BIN" -p "/wip-crawl" \
  --output-format json --dangerously-skip-permissions > "$RESULT" 2>> "$LOG"; then
  status=0
else
  status=$?
fi
cat "$RESULT" >> "$LOG"
printf '\n' >> "$LOG"
if [ "$status" -eq 0 ] && ! jq -s -e '
  length == 1 and (.[0] |
    type == "object" and .type == "result" and .subtype == "success" and
    .is_error == false and (.result | type == "string") and
    (.result | test("^(Failed to authenticate:|Unknown command:)") | not))
' "$RESULT" >> "$LOG" 2>&1; then
  echo "$(date '+%F %T') invalid or failed Claude result" >> "$LOG"
  status=1
fi
if [ "$status" -ne 0 ]; then
  echo "$(date '+%F %T') claude failed (exit=$status)" >> "$LOG"
  exit "$status"
fi
echo "$(date '+%F %T') done" >> "$LOG"
