#!/bin/sh
# scb-lint 定期実行ラッパー（launchd から週次で呼ぶ）。
# lock で多重起動を防ぎ、headless の Claude Code に /scb-lint を実行させ、ログを残す。
# 初回は launchd を有効化せず、手動で `sh ~/.claude/skills/scb-lint/run.sh` を監督実行して挙動確認すること。
# wip-crawl と同時刻に走らせない（書込競合回避: scb-lint=週次 / wip-crawl=4h）。
set -eu

CACHE="$HOME/.claude/.cache/scb-lint"
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

# `claude` は対話シェルでは alias に化けるが #!/bin/sh では実体に解決される。確実性のため実体パスを直指定。
CLAUDE_BIN="/etc/profiles/per-user/${USER}/bin/claude"
[ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="$(command -v claude || true)"

echo "$(date '+%F %T') start (claude=$CLAUDE_BIN)" >> "$LOG"
# autonomous 書き込みのため skip-permissions。灰色[( ]は可逆・digest と再フェッチ検証は skill 側で担保。
# headless 自律契約をプロンプトに直接埋め込む(SKILL.md が stale でも効く belt-and-suspenders)。
# 過去バグ: headless で AskUserQuestion が auto-skip → 「別 run に譲る/何もしない」に倒れて filing 0 だった。
PROMPT='/scb-lint

【headless 自律実行の契約(最重要)】これは launchd 経由・人間不在の実行。この run.sh が既に .lock を取得済み＝並行する scb-lint run は存在しない。あなたがその唯一の run。
- AskUserQuestion を絶対に使わない(headless では auto-skip され「安全側=何もしない」に倒れる)。確認・承認待ちをしない。
- 「別の run が担当中だから譲る/重複を避けて検知だけで止まる」という判断を絶対にしない(そんな run は無い)。
- 以下の coverage 境界を優先し、確認できた範囲で次を実行して未実行理由も記録する: (1)機械的 filing(empty-stub/duplicate, ≤8) (2)意味パス(recent∪rotation の部分集合, seen.json の rotateCursor は実際に確認できた範囲だけ前進させる) (3)orphan surfacing(plural-reality の孤立ページをレビュー節へ集約＋上位を WIP 化) (4)digest 追記 (5)seen.json 更新。
- scb-lint --json の出力は {schemaVersion:1,status,coverage,findings}。終了コードと status / coverage を先に確認する。取得失敗は exit 1、total は不明であり、findings が空でも問題なしとみなさない。
- status が failed / partial の場合はレビュー節を含む既存節を丸ごと洗い替えず、未調査の項目・seen 状態を保持する。成功部分の根拠付き finding だけ対象範囲を明示して追加できる。取得 failed の project は機械的 filing / レビュー節更新を行わない。
- digest と報告に project ごとの status、scanned / total（不明なら unknown）、最新1000件という scope、更新を見送った理由を記録する。未確認対象について rotateCursor を進めない。この coverage 境界は上の全工程実行指示に優先する。
- 途中で迷っても、この coverage 境界と skill の既定値で進める。'
"$CLAUDE_BIN" -p "$PROMPT" --dangerously-skip-permissions >> "$LOG" 2>&1 || echo "$(date '+%F %T') claude exited $?" >> "$LOG"
echo "$(date '+%F %T') done" >> "$LOG"
