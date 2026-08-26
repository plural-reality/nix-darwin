#!/usr/bin/env bash
# Scrapbox connect.sid を「静的な文字列」ではなく「ログイン済み Chrome セッションの関数」として
# 実行時に再生成する。SID は定期失効し、失効すると cosense-fetch / 横断検索 / Scrapbox 書込 /
# wip-crawl / scb-lint / todo-kanban-autoupdate が全プロジェクトで guest 落ちする。その単一障害点を、
# 「Chrome Cookie を復号 → /api/users/me で検証 → settings.local.json に注入」で自己修復する。
#
#   f() = decrypt(chrome_profile_cookie) |> verify(/me isGuest==false) |> inject(settings.local.json)
#
# 出力: 検証済み SID を stdout に 1 行。副作用: 有効時のみ settings.local.json の env.SCRAPBOX_SID を更新。
# 終了コード: 0=有効な SID を取得/注入, 1=取得失敗(呼び手は既存 env にフォールバック可)。
#
# ponytail: keychain 読取は初回のみ GUI 許可が要る(Chrome Safe Storage)。launchd(Aqua) 実行では
#   ログインセッションが生きていれば無音で通る。GUI ロック中/未ログインでは失敗し exit 1(既存 SID 維持)。
set -uo pipefail

CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
SETTINGS="${SETTINGS:-$HOME/.claude/settings.local.json}"

ensure_settings_mode() {
  [ ! -e "$SETTINGS" ] && [ ! -L "$SETTINGS" ] && return 0
  [ -f "$SETTINGS" ] && [ ! -L "$SETTINGS" ] || {
    echo "settings.local.json は通常ファイルでなければならない" >&2
    return 1
  }
  /bin/chmod 600 "$SETTINGS" || {
    echo "settings.local.json の権限更新に失敗" >&2
    return 1
  }
}

# 1) scrapbox connect.sid を持つ Chrome プロファイルのうち mtime 最新のものを選ぶ(現用プロファイル)。
#    Profile 5 固定にしない — 現用が変わっても「最新に更新された Cookie DB」で追従する。
pick_profile() {
  local best="" best_mtime=0 c prof m n
  for c in "$CHROME_DIR"/*/Cookies; do
    [ -e "$c" ] || continue
    prof=$(dirname "$c")
    n=$(sqlite3 "$c" "SELECT count(*) FROM cookies WHERE host_key LIKE '%scrapbox.io%' AND name='connect.sid';" 2>/dev/null) || continue
    [ "${n:-0}" -gt 0 ] || continue
    m=$(stat -f '%m' "$c" 2>/dev/null) || continue
    if [ "$m" -gt "$best_mtime" ]; then best_mtime=$m; best="$c"; fi
  done
  [ -n "$best" ] && printf '%s' "$best"
}

main() {
  ensure_settings_mode || exit 1

  COOKIE_DB=$(pick_profile) || true
  [ -z "${COOKIE_DB:-}" ] && { echo "no chrome profile with scrapbox connect.sid" >&2; exit 1; }

  # Cookies DB は Chrome 稼働中ロックされるので複製してから読む。
  TMPDB=$(mktemp) || exit 1
  trap 'rm -f "$TMPDB"' EXIT
  cp "$COOKIE_DB" "$TMPDB" || exit 1

  PW=$(security find-generic-password -w -s "Chrome Safe Storage" 2>/dev/null) || {
    echo "keychain: Chrome Safe Storage 読取失敗(GUI許可/ロック?)" >&2; exit 1; }
  ENC=$(sqlite3 "$TMPDB" "SELECT quote(encrypted_value) FROM cookies WHERE host_key LIKE '%scrapbox.io%' AND name='connect.sid' ORDER BY LENGTH(encrypted_value) DESC LIMIT 1;") || exit 1

# 2) 復号(AES-128-CBC / PBKDF2-SHA1 派生鍵)。cryptography/browser_cookie3 非依存 = hashlib+openssl。
  SID=$(python3 - "$PW" "$ENC" <<'PY' || true
import sys, hashlib, subprocess, urllib.parse
pw = sys.argv[1].encode()
q = sys.argv[2].strip()
if not q.startswith("X'"):
    sys.exit(1)
raw = bytes.fromhex(q[2:-1])
if raw[:3] != b'v10':
    sys.exit(1)
key = hashlib.pbkdf2_hmac('sha1', pw, b'saltysalt', 1003, 16)
p = subprocess.run(['openssl','enc','-aes-128-cbc','-d','-K',key.hex(),'-iv',(b' '*16).hex(),'-nopad'],
                   input=raw[3:], capture_output=True)
dec = p.stdout
if not dec:
    sys.exit(1)
pad = dec[-1]
if 1 <= pad <= 16:
    dec = dec[:-pad]
# 新しめ macOS Chrome は平文の前に 32 byte の sha256 domain prefix を付ける。
val = dec[32:].decode('utf-8', 'replace')
print(urllib.parse.unquote(val))
PY
)
  [ -z "${SID:-}" ] && { echo "decrypt failed" >&2; exit 1; }

  # 3) /api/users/me で検証。isGuest=true なら失効しているので注入しない。
  ME=$(curl -s --max-time 8 -H "Cookie: connect.sid=${SID}" https://scrapbox.io/api/users/me 2>/dev/null || true)
  case "$ME" in
    *'"isGuest":true'*|'') echo "decrypted SID is guest/invalid" >&2; exit 1 ;;
  esac
  echo "$ME" | grep -q '"name"' || { echo "unexpected /me response" >&2; exit 1; }

  # 4) settings.local.json の env.SCRAPBOX_SID を原子的に注入(有効時のみ)。JSON 妥当性を確認してから置換。
  if [ -f "$SETTINGS" ]; then
    CUR=$(jq -r '.env.SCRAPBOX_SID // ""' "$SETTINGS" 2>/dev/null || true)
    if [ "$CUR" != "$SID" ]; then
      TMPJSON=$(mktemp "${SETTINGS}.tmp.XXXXXX") || exit 1
      /bin/chmod 600 "$TMPJSON"
      if jq --arg s "$SID" '.env.SCRAPBOX_SID = $s' "$SETTINGS" > "$TMPJSON" 2>/dev/null && jq -e . "$TMPJSON" >/dev/null 2>&1; then
        mv "$TMPJSON" "$SETTINGS"
        echo "injected fresh SID into settings.local.json" >&2
      else
        rm -f "$TMPJSON"; echo "settings.local.json 更新失敗(JSON壊れず維持)" >&2
      fi
    fi
  fi

  printf '%s' "$SID"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
