#!/usr/bin/env bash
# session-summary.sh — SessionEnd hook(async)。終了した1セッションを LLM で要約・分類し、
#                      その日の summaries-<DATE>.jsonl に1行追記する(冪等)。
#
# 抽象:  f(stdin: SessionEnd JSON) -> append(summaries.jsonl) | ∅
#        Scrapbox 反映は別段(daily-page.py)。ここは「収集された生トーク履歴 → 構造化要約」変換に徹する。
#
# 無限ループ回避(最重要):
#   要約は `claude -p` を呼ぶ = それ自身が SessionEnd を撃つ。--bare は hooks を切るが認証も切れて
#   "Not logged in" になるため使えない。代わりに要約 claude を CLAUDE_DAILY_SUMMARY=1 で起動し、
#   その子プロセスである本フックが先頭ガードで即 exit する。env は子へ継承されるのでこれで再帰が止まる。
#
# 冪等性:  session_id を summaries に刻むので、同一セッションの再 SessionEnd は二度要約しない。
# 安全性:  短い(雑談/確認のみ)セッションは要約しない。不正 JSON / 認証断は無音で exit 0(gather を壊さない)。
set -uo pipefail

# --- 再帰ガード: 要約用 claude 自身の SessionEnd を握りつぶす ---
[ "${CLAUDE_DAILY_SUMMARY:-}" = "1" ] && exit 0

# --- 完了通知: 「前セッションをここに保存したよ」をユーザーへ。
#     terminal-notifier があれば -open でクリック→ブラウザで Scrapbox ページが開く。
#     無ければ osascript(クリック不可だが URL は読める)へフォールバック。SessionStart の
#     stdout はユーザー画面に出ないため、確実に見せられるのはこのデスクトップ通知だけ。
notify_saved() {
  local proj="$1" msg="$2" url="$3"
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "📝 Claude Code" -subtitle "✅ 前セッションを記録 (${proj})" \
      -message "${msg}" -open "${url}" -sound Glass -group "claude-daily-report" >/dev/null 2>&1 || true
  else
    osascript -e 'on run argv' \
      -e 'display notification (item 2 of argv) with title "📝 Claude Code" subtitle (item 1 of argv) sound name "Glass"' \
      -e 'end run' "✅ 前セッションを記録 (${proj})" "${msg} — ${url}" >/dev/null 2>&1 || true
  fi
}

readonly input="$(cat)"
readonly sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
readonly tpath="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
readonly cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
{ [ -n "$sid" ] && [ -n "$tpath" ] && [ -f "$tpath" ]; } || exit 0

readonly DATE="$(TZ=Asia/Tokyo date +%Y-%m-%d)"
readonly CACHE="$HOME/.claude/.cache/daily-report"
readonly SUMMARIES="$CACHE/summaries-$DATE.jsonl"
mkdir -p "$CACHE"

# --- 冪等: このセッションを既に要約済みなら何もしない ---
{ [ -f "$SUMMARIES" ] && grep -qF "\"session_id\":\"$sid\"" "$SUMMARIES"; } && exit 0

# --- トーク履歴を要約用ダイジェストに圧縮(決定的) ---
#     user 発話 + Edit/Write 対象ファイル + 最後の assistant。短すぎるセッションは exit 1 で捨てる。
readonly digest="$(python3 - "$tpath" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
prompts, files, last_assistant, user_chars = [], [], "", 0
for line in open(path):
    try: o = json.loads(line)
    except Exception: continue
    t = o.get("type"); m = o.get("message", {}) or {}; c = m.get("content")
    text = c if isinstance(c, str) else (
        "".join(b.get("text","") for b in c if isinstance(b, dict) and b.get("type") == "text")
        if isinstance(c, list) else "")
    if t == "user":
        s = " ".join(text.split())
        if s and not s.startswith("<") and "Caveat" not in s[:30]:
            prompts.append(s[:300]); user_chars += len(s)
    elif t == "assistant":
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") in ("Edit", "Write", "NotebookEdit"):
                    fp = (b.get("input") or {}).get("file_path", "")
                    if fp and fp.split("/")[-1] not in files:
                        files.append(fp.split("/")[-1])
        if text.strip():
            last_assistant = " ".join(text.split())[:300]
# 雑談・確認のみ(実質的依頼なし)は要約に値しない
if not prompts or user_chars < 40:
    sys.exit(1)
out = "ユーザーの依頼:\n" + "\n".join(f"- {p}" for p in prompts[:8])
if files: out += "\n変更ファイル: " + ", ".join(files[:15])
if last_assistant: out += "\n最後の応答: " + last_assistant
print(out[:2000])
PY
)"
[ -z "$digest" ] && exit 0

# --- LLM で要約 + プロジェクト分類(haiku) ---
readonly cwd_base="$(printf '%s' "$cwd" | sed 's#/*$##; s#.*/##')"
readonly prompt="次の Claude Code セッションを要約・分類せよ。JSON を1行だけ出力し、コードブロックや説明は一切書くな。
形式: {\"project\":\"plural-reality\" または \"tkgshn-private\",\"summary\":\"成果を1文で簡潔に(日本語)\"}
分類基準: plural-reality = チーム/プロダクト開発(website・baisoku-survey・cartographer 等)。tkgshn-private = 個人ツール/環境構築/Claude設定/雑務。
作業ディレクトリ: ${cwd_base}

${digest}"

readonly raw="$(CLAUDE_DAILY_SUMMARY=1 claude -p --model claude-haiku-4-5 "$prompt" 2>/dev/null || true)"
# ```json フェンスや前後ノイズを剥がして最初の { … } を取り出す
readonly cleaned="$(printf '%s' "$raw" | tr -d '\n' | sed 's/```json//g; s/```//g; s/^[^{]*//; s/[^}]*$//')"

# 妥当な JSON(project と summary がある)だけを採用し、session_id と time を刻んで追記。
# hash(=sid[:8]) はシェルが決定的に付与する唯一のハッシュ(daily-flush.py が work の #hash に使う)。
printf '%s' "$cleaned" | jq -e '.project and .summary' >/dev/null 2>&1 || exit 0
readonly proj="$(printf '%s' "$cleaned" | jq -r '.project')"
readonly oneline="$(printf '%s' "$cleaned" | jq -r '.summary')"
printf '%s' "$cleaned" | jq -c \
  --arg sid "$sid" --arg time "$(TZ=Asia/Tokyo date +%H:%M)" --arg hash "${sid:0:8}" \
  '{project, summary, session_id: $sid, time: $time, hash: $hash}' \
  >> "$SUMMARIES" || exit 0

# 要約を1件追記できたので、その日の全 summaries を Scrapbox 日付ページへ反映(冪等・project ごと)。
# async hook 内なので元セッションをブロックしない。SCRAPBOX_SID は settings.json env から継承。
# 副作用として last-saved.json(記録先 URL の唯一の機械可読ソース)も更新される。
python3 "$HOME/.claude/scripts/daily-flush.py" "$DATE" >/dev/null 2>&1 || true

# --- ユーザーへ完了通知。URL は daily-flush.py が書いた last-saved.json から引く
#     (scrapbox 名の権威は daily-flush の PROJECTS 一箇所に集約 → ここでは再定義しない)。
readonly LAST="$CACHE/last-saved.json"
readonly url="$( { [ -f "$LAST" ] && jq -r --arg p "$proj" '.pages[]? | select(.project==$p) | .url' "$LAST" 2>/dev/null | head -1; } || true )"
[ -n "$url" ] && notify_saved "$proj" "$oneline" "$url"
