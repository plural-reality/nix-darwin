#!/usr/bin/env bash
# session-title-refine.sh — UserPromptSubmit hook (非同期 / async:true)
#
# 目的: 初回プロンプトから Haiku で「日本語の簡潔なタイトル」を生成し、
#       $CACHE_DIR/$SID.title に書き出す。同時に tmux / OSC 端末タイトルも即更新する。
#       Claude Code の custom-title への反映は同期側 (auto-rename-from-prompt.sh) が
#       次の UserPromptSubmit で apply-once 回収する (本hookはJSONを返さない=非同期のため)。
#
# 設計原則:
#   - fail-open: あらゆる失敗で静かに exit 0 (プロンプトを決してブロックしない)。
#   - 冪等: .title が既にあれば何もしない。初回メッセージ以外も何もしない。
#   - 再帰防止: 生成用の子 claude は CLAUDE_AUTO_TITLE=1/CLAUDE_DAILY_SUMMARY=1 で起動。
#     → auto-rename / prompt-context-inject / session-summary / daily-report-capture を全て握りつぶす。
set -uo pipefail

# --- 再帰ガード: タイトル生成用 claude 自身の UserPromptSubmit を無視 ---
[ "${CLAUDE_AUTO_TITLE:-}" = "1" ] && exit 0

readonly INPUT="$(cat 2>/dev/null || true)"
readonly PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || true)"
readonly TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
readonly SID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
readonly CACHE_DIR="$HOME/.claude/.cache/session-titles"
readonly TITLE_FILE="$CACHE_DIR/$SID.title"

# 必須入力が無ければ即終了
{ [ -n "$SID" ] && [ -n "$PROMPT" ]; } || exit 0

# 冪等: 既に生成済みなら何もしない
[ -f "$TITLE_FILE" ] && exit 0

# 初回メッセージのみ対象 (assistant 発言がある = 2回目以降 → スキップ)
if [ -f "$TRANSCRIPT" ]; then
  # grep -c は no-match で "0" を出力しつつ exit 1 → `|| echo 0` は二重出力でバグる。`|| true` + 既定0 で吸収。
  n="$(grep -c '"role":"assistant"' "$TRANSCRIPT" 2>/dev/null || true)"
  [ "${n:-0}" -eq 0 ] || exit 0
fi

# フォーク時の caveat 等、'<' で始まる擬似プロンプトはタイトルに不適 → スキップ
case "$PROMPT" in '<'*) exit 0 ;; esac

# タイトル正規化: 改行除去 → 前後空白除去 → 前後の引用符/括弧はぎ取り → 24字でカット
sanitize_title() {
  printf '%s' "$1" \
    | tr -d '\n\r' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e 's/^["“”「『`]\{1,\}//' -e 's/["“”」』`]\{1,\}$//' \
    | cut -c1-24
}

readonly INSTR="次の作業依頼に、日本語で簡潔なタイトルを1つ付けよ。条件: 12文字程度・最大18文字 / 体言止め / 記号・引用符・接頭辞(「タイトル:」等)・改行を一切付けない / タイトル本文のみを1行で出力。

依頼:
${PROMPT}"

# Haiku で生成 (子 claude は再帰ガード環境変数つき・MCP 読み込みなしで高速化)
raw="$(CLAUDE_AUTO_TITLE=1 CLAUDE_DAILY_SUMMARY=1 claude -p --model claude-haiku-4-5 --strict-mcp-config "$INSTR" 2>/dev/null || true)"
title="$(sanitize_title "$raw")"
[ -z "$title" ] && exit 0

# アトミック書き込み (PID つき一時ファイル → mv)
mkdir -p "$CACHE_DIR" 2>/dev/null || true
tmp="$CACHE_DIR/.$SID.$$.tmp"
printf '%s' "$title" > "$tmp" 2>/dev/null && mv -f "$tmp" "$TITLE_FILE" 2>/dev/null || true

# 端末タイトルは即時更新 (custom-title は同期側が次プロンプトで回収)
if [ -n "${TMUX:-}" ]; then
  tmux rename-session "$title" 2>/dev/null || true
  tmux set-window-option automatic-rename off 2>/dev/null || true
fi
printf '\033]0;%s\007' "$title" > /dev/tty 2>/dev/null || true

# 後始末: 14日より古いキャッシュを掃除
find "$CACHE_DIR" -type f -mtime +14 -delete 2>/dev/null || true

exit 0
