#!/bin/bash
set +H 2>/dev/null  # bash history expansion を無効化（! の問題を回避）
# Beeper Desktop API — メッセージ送受信・スレッド操作スクリプト
# 単一 canonical CLI。read-back / reply-in-thread / delete をワンコマンド化してトークン節約。
#
# Usage:
#   beeper-send.sh search "query"                  チャットをタイトル/内容で検索 → chatID
#   beeper-send.sh chats [limit]                   最近のチャット一覧
#   beeper-send.sh messages CHAT_ID [limit]        直近メッセージを新しい順で表示(id/reply→/sender/ts/本文)
#   beeper-send.sh thread CHAT_ID MSG_ID           MSG_ID が属するスレッド(返信チェーン)を復元表示
#   beeper-send.sh send  CHAT_ID  BODY             新規メッセージ送信 (スレッドなし)
#   beeper-send.sh reply CHAT_ID REPLY_TO_ID BODY  元メッセージへのスレッド返信(reply-in-thread)
#   beeper-send.sh delete CHAT_ID MSG_ID           メッセージ取り消し(自分の投稿)
#   beeper-send.sh send-to SHORTCUT BODY           ショートカット宛に新規送信
#
#   BODY は次のいずれか:
#     @/path/to/file   ファイルから UTF-8 で読む(日本語は必ずこれ。argv 経由は agent zsh で文字化け)
#     "literal text"    ASCII 向けのリテラル
#
# send/reply は受理後に自動 read-back し、反映 (reply は linkedMessageID=親) を表示する。

set -euo pipefail

API_BASE="http://localhost:23373"
TOKEN_FILE="$HOME/.config/beeper/token"
# Beeper CRM gateway (shared per-person style guide + learning loop). All calls
# here are best-effort / fail-open: if the gateway is down the send path is
# unaffected. See docs/SHARED_STYLE_GUIDE.md in beeper-scrapbox-crm.
CRM_BASE="${BEEPER_CRM_GATEWAY:-http://localhost:8787}"

# ショートカット → Chat ID 変換
resolve_shortcut() {
  case "$1" in
    tagen)  echo '!ELVrLbW4IRgnOGBHAVSt:beeper.local' ;;
    tanaka) echo '!wmTwjvAuhzx58vZYQZBX:beeper.local' ;;
    zos)    echo '!fEmwCiXwhgRPnqvLpD:beeper.com' ;;
    *)      echo "" ;;
  esac
}

# トークン読み取り
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERROR: Token file not found at $TOKEN_FILE" >&2
  exit 1
fi
TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE")

# Chat ID を URL エンコード（! と : をエスケープ）
url_encode_chat_id() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# API呼び出しヘルパー
api_get() {
  curl -g -sf -H "Authorization: Bearer $TOKEN" "${API_BASE}$1"
}
api_post() {
  curl -g -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${API_BASE}$1" --data-binary "@$2"
}
api_delete() {
  curl -g -s -o /dev/null -w "%{http_code}" -X DELETE -H "Authorization: Bearer $TOKEN" "${API_BASE}$1"
}

# BODY 指定(@file または literal)と任意の replyToID から JSON payload を作り、一時ファイルパスを stdout に返す。
# 日本語は @file 経由＋ensure_ascii=False で文字化けを回避する。呼び出し側で rm すること。
build_payload_file() {
  local body_spec="$1" reply_to="${2:-}"
  local out
  out=$(mktemp)
  BODY_SPEC="$body_spec" REPLY_TO="$reply_to" python3 - "$out" <<'PY'
import json, os, sys
spec = os.environ["BODY_SPEC"]
reply = os.environ.get("REPLY_TO", "")
if spec.startswith("@"):
    with open(spec[1:], encoding="utf-8") as f:
        text = f.read().rstrip("\n")
else:
    text = spec
obj = {"text": text}
if reply:
    obj["replyToMessageID"] = str(reply)  # API は string を要求する
with open(sys.argv[1], "w", encoding="utf-8") as o:
    o.write(json.dumps(obj, ensure_ascii=False))
PY
  echo "$out"
}

# 新しい順でメッセージ一覧を整形表示する。
print_messages() {
  local enc="$1" limit="${2:-15}"
  local tmp
  tmp=$(mktemp)
  api_get "/v1/chats/$enc/messages?limit=$limit&direction=before&cursor=99999999" > "$tmp"
  python3 - "$tmp" <<'PY'
import sys, json, re
d = json.load(open(sys.argv[1], encoding="utf-8"))
def clean(t):
    t = re.sub(r"<br\s*/?>", " ", t or "")
    t = re.sub(r"</p>", " ", t)
    t = re.sub(r"<[^>]+>", "", t)
    return " ".join(t.split())
items = d.get("items", [])
for i in items:  # API は新しい順(先頭=newest)で返す
    rid = i.get("linkedMessageID")
    flag = "DEL" if i.get("isDeleted") else "   "
    rep = ("reply->%s" % rid) if rid else "         -"
    body = clean(i.get("text")) or ("<%s>" % i.get("type", ""))
    print("%s %-8s %-14s %-13s %-16s | %s" % (
        flag, i.get("id"), rep, (i.get("senderName") or "")[:14],
        (i.get("timestamp") or "")[5:19], body[:84]))
print("\n(%d 件・新しい順。reply-> は親メッセージID=スレッド)" % len(items))
PY
  rm -f "$tmp"
}

case "${1:-help}" in
  search)
    query="${2:?Usage: beeper-send.sh search QUERY}"
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query")
    api_get "/v1/chats/search?query=$encoded" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data.get('items', []):
    print(f\"{c['id']} | {c.get('title','')} | {c.get('network','')}\")
if not data.get('items'):
    print('No results found')
"
    ;;

  chats)
    limit="${2:-20}"
    api_get "/v1/chats?limit=$limit" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data.get('items', []):
    print(f\"{c.get('network',''):10} | {c.get('title',''):40} | {c['id']}\")
"
    ;;

  messages)
    chat_id="${2:?Usage: beeper-send.sh messages CHAT_ID [limit]}"
    limit="${3:-15}"
    print_messages "$(url_encode_chat_id "$chat_id")" "$limit"
    ;;

  thread)
    chat_id="${2:?Usage: beeper-send.sh thread CHAT_ID MSG_ID}"
    msg_id="${3:?Usage: beeper-send.sh thread CHAT_ID MSG_ID}"
    enc=$(url_encode_chat_id "$chat_id")
    tmp=$(mktemp)
    # スレッド復元のため十分な履歴を取る(window制限あり=ponytail: 50件超のスレッドは末尾が欠ける)
    api_get "/v1/chats/$enc/messages?limit=80&direction=before&cursor=99999999" > "$tmp"
    MSG_ID="$msg_id" python3 - "$tmp" <<'PY'
import sys, json, re, os
d = json.load(open(sys.argv[1], encoding="utf-8"))
target = str(os.environ["MSG_ID"])
by_id = {str(i.get("id")): i for i in d.get("items", [])}
def clean(t):
    t = re.sub(r"<br\s*/?>", " ", t or ""); t = re.sub(r"</p>", " ", t); t = re.sub(r"<[^>]+>", "", t)
    return " ".join(t.split())
if target not in by_id:
    print("MSG_ID %s が直近80件に見つかりません。limit を増やすか messages で確認を。" % target); sys.exit(0)
# 親方向にrootへ遡る
root = target
seen = set()
while True:
    p = by_id.get(root, {}).get("linkedMessageID")
    p = str(p) if p is not None else None
    if not p or p not in by_id or p in seen:
        break
    seen.add(p); root = p
# rootに(推移的に)到達する子孫を集める
def reaches_root(mid):
    cur, guard = mid, 0
    while cur and guard < 200:
        if cur == root: return True
        nxt = by_id.get(cur, {}).get("linkedMessageID")
        cur = str(nxt) if nxt is not None else None; guard += 1
    return False
chain = [i for i in d.get("items", []) if str(i.get("id")) == root or reaches_root(str(i.get("id")))]
chain.sort(key=lambda i: i.get("sortKey", 0))
print("=== スレッド (root=%s, %d 件) ===" % (root, len(chain)))
for i in chain:
    mark = " <-- 指定" if str(i.get("id")) == target else ("  [root]" if str(i.get("id")) == root else "")
    print("%-8s %-14s %-16s%s\n    %s" % (
        i.get("id"), (i.get("senderName") or "")[:14], (i.get("timestamp") or "")[5:19],
        mark, clean(i.get("text"))[:120]))
print("\n→ このスレッドに返すなら: beeper-send.sh reply CHAT_ID <上の親候補ID> @file")
PY
    rm -f "$tmp"
    ;;

  style)
    # 起草前に、この相手の共有文体ガイド(Scrapbox [** CRM 文体ガイド] 由来)を
    # CRM gateway から引く。gateway が唯一の join/parse 実装なので、ここでは
    # chatID を渡すだけ。fail-open: 取得できなければ memory の文体メモに戻る。
    chat_id="${2:?Usage: beeper-send.sh style CHAT_ID}"
    enc=$(url_encode_chat_id "$chat_id")
    resp=$(curl -g -s --max-time 5 "${CRM_BASE}/api/style?chat=$enc" || true)
    CRM_STYLE_RESP="$resp" python3 <<'PY'
import os, json, sys
raw = os.environ.get("CRM_STYLE_RESP", "").strip()
if not raw:
    print("(no style guide: CRM gateway unreachable — fall back to memory tone guide)"); sys.exit(0)
try:
    d = json.loads(raw)
except Exception:
    print("(no style guide: non-JSON response — fall back to memory tone guide)"); sys.exit(0)
if isinstance(d, dict) and d.get("code"):
    print(f"(no style guide: {d.get('code')} — {str(d.get('message',''))[:80]})"); sys.exit(0)
print(f"contactId={d.get('contactId','')}")
print(f"memoTitle={d.get('memoTitle','')}")
rules = d.get("rules", [])
if rules:
    print("# 文体ルール (human=人間承認・優先 / auto=学習済)")
    for r in rules:
        print(f"- [{r.get('origin')}] {r.get('text')}")
else:
    print("# 文体ルール: (未登録)")
if str(d.get("userVoice", "")).strip():
    print("# 送信者voice(全体)\n" + d["userVoice"].strip())
if str(d.get("relationshipGoal", "")).strip():
    print("# 関係性ゴール\n" + d["relationshipGoal"].strip())
PY
    ;;

  report-edit)
    # 送信した文面が AI 下書きと違った(=人間が直した)ときだけ呼ぶ。差分を
    # external.edited として CRM に報告し、双方向学習ループに乗せる。
    # contactId は直前の `style` 出力の contactId= 行から取る。fail-open。
    contact_id="${2:?Usage: beeper-send.sh report-edit CONTACT_ID @original @final [CHAT_ID]}"
    orig="${3:?Usage: report-edit CONTACT_ID @original @final [CHAT_ID]  (AI下書き)}"
    final="${4:?Usage: report-edit CONTACT_ID @original @final [CHAT_ID]  (実際に送った文面)}"
    chat_id="${5:-}"
    pf=$(mktemp)
    CONTACT_ID="$contact_id" CHAT_ID="$chat_id" ORIG_SPEC="$orig" FINAL_SPEC="$final" python3 - "$pf" <<'PY'
import os, json, sys, datetime
def read_spec(s):
    return open(s[1:], encoding="utf-8").read().rstrip("\n") if s.startswith("@") else s
obj = {
    "type": "external.edited",
    "contactId": os.environ["CONTACT_ID"],
    "source": "beeper-send",
    "originalText": read_spec(os.environ["ORIG_SPEC"]),
    "finalText": read_spec(os.environ["FINAL_SPEC"]),
    "occurredAt": datetime.datetime.now(datetime.timezone.utc)
        .isoformat().replace("+00:00", "Z"),
}
cid = os.environ.get("CHAT_ID", "").strip()
if cid:
    obj["chatId"] = cid
with open(sys.argv[1], "w", encoding="utf-8") as o:
    o.write(json.dumps(obj, ensure_ascii=False))
PY
    code=$(curl -g -s -o /dev/null -w "%{http_code}" --max-time 5 -X POST \
      -H "Content-Type: application/json" \
      "${CRM_BASE}/api/promptops/events" --data-binary "@$pf" || echo "000")
    rm -f "$pf"
    echo "report-edit -> HTTP $code (contactId=$contact_id)"
    [[ "$code" == "200" ]] || echo "(non-200: best-effort learning skipped — safe to ignore)"
    ;;

  send)
    chat_id="${2:?Usage: beeper-send.sh send CHAT_ID BODY}"
    body="${3:?Usage: beeper-send.sh send CHAT_ID BODY  (BODY=@file or text)}"
    enc=$(url_encode_chat_id "$chat_id")
    pf=$(build_payload_file "$body")
    api_post "/v1/chats/$enc/messages" "$pf"; echo
    rm -f "$pf"
    echo "OK: sent (new). read-back:"
    sleep 5; print_messages "$enc" 2 || true
    ;;

  reply)
    chat_id="${2:?Usage: beeper-send.sh reply CHAT_ID REPLY_TO_ID BODY}"
    reply_to="${3:?Usage: beeper-send.sh reply CHAT_ID REPLY_TO_ID BODY}"
    body="${4:?Usage: beeper-send.sh reply CHAT_ID REPLY_TO_ID BODY  (BODY=@file or text)}"
    enc=$(url_encode_chat_id "$chat_id")
    pf=$(build_payload_file "$body" "$reply_to")
    api_post "/v1/chats/$enc/messages" "$pf"; echo
    rm -f "$pf"
    echo "OK: replied in-thread to $reply_to. read-back (linkedMessageID が $reply_to なら成功):"
    sleep 6; print_messages "$enc" 2 || true
    ;;

  delete)
    chat_id="${2:?Usage: beeper-send.sh delete CHAT_ID MSG_ID}"
    msg_id="${3:?Usage: beeper-send.sh delete CHAT_ID MSG_ID}"
    enc=$(url_encode_chat_id "$chat_id")
    code=$(api_delete "/v1/chats/$enc/messages/$msg_id")
    echo "DELETE -> HTTP $code"
    echo "read-back:"; sleep 3; print_messages "$enc" 3 || true
    ;;

  send-to)
    shortcut="${2:?Usage: beeper-send.sh send-to SHORTCUT BODY}"
    body="${3:?Usage: beeper-send.sh send-to SHORTCUT BODY}"
    chat_id=$(resolve_shortcut "$shortcut")
    if [[ -z "$chat_id" ]]; then
      echo "ERROR: Unknown shortcut '$shortcut'. Available: tagen, tanaka, zos" >&2
      exit 1
    fi
    enc=$(url_encode_chat_id "$chat_id")
    pf=$(build_payload_file "$body")
    api_post "/v1/chats/$enc/messages" "$pf"; echo
    rm -f "$pf"
    echo "OK: sent to $shortcut. read-back:"
    sleep 5; print_messages "$enc" 2 || true
    ;;

  help|*)
    cat <<'EOF'
Beeper Desktop API — Message Sender / Thread tool

Commands:
  search QUERY               チャットを検索 → chatID
  chats [LIMIT]              最近のチャット一覧
  messages CHAT_ID [LIMIT]   直近メッセージ(新しい順, id/reply->親/sender/ts/本文)
  thread CHAT_ID MSG_ID      MSG_ID のスレッド(返信チェーン)を復元
  style CHAT_ID              この相手の共有文体ガイド(CRM)を引く(起草前・fail-open)
  send  CHAT_ID  BODY        新規送信(スレッドなし)
  reply CHAT_ID REPLY_TO_ID BODY   元メッセージへスレッド返信(既定はこちら)
  report-edit CONTACT_ID @orig @final [CHAT_ID]  人間が直した差分をCRMに報告(学習)
  delete CHAT_ID MSG_ID      自分の投稿を取り消し
  send-to SHORTCUT BODY      ショートカット宛に新規送信

BODY:
  @/path/to/file   ファイルから UTF-8 で読む(日本語は必ずこれ)
  "literal"        ASCII リテラル

Shortcuts:
  tagen  → 多元チャンネル (構想日本 Slack)
  tanaka → 田中俊 DM (構想日本 Slack)
  zos    → zos (Beeper Matrix グループ)

鉄則: 関連する既存スレッドがあれば reply で in-thread に返す。channel 直投稿で会話を分断しない。
EOF
    ;;
esac
