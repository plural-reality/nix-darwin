#!/usr/bin/env bash
# signed-bridge-check.sh — Claude Code SessionStart hook
# 署名済み bridge(TCC を持つ per-user daemon)の署名証明書の期限を確認する。
#
# なぜ要るか: 証明書が切れると build.sh は fail closed で署名を拒む。すると source を
# 更新しても署名し直せず、**古いバイナリが動き続ける**。署名済みバイナリは失効後も実行
# できるので daemon は健全に見え、次に誰かがビルドするまで表面化しない。実際に
# 2026-08-03 に失効した証明書が 8/18 まで気付かれず、bridge の修正を適用したのに
# daemon は古いままだった。
#
# 対象は「今デプロイされている app」から逆に引く。identity の設定は downstream の
# personal.nix にあるので、ここに書くと第2の定義になる。app の署名そのものが正本。
#
# 失敗時は exit 0（起動をブロックしない）

set -uo pipefail

WARN_SECONDS="${SIGNED_BRIDGE_WARN_SECONDS:-2592000}"  # 30日
BASE="${SIGNED_BRIDGE_BASE:-$HOME/Library/Application Support}"
# 既定は絶対パス(PATH に依存しない)。テストが keychain を触らずに済むよう差し替え可能にする。
CODESIGN="${SIGNED_BRIDGE_CODESIGN:-/usr/bin/codesign}"
SECURITY="${SIGNED_BRIDGE_SECURITY:-/usr/bin/security}"
OPENSSL="${SIGNED_BRIDGE_OPENSSL:-/usr/bin/openssl}"

# app bundle: generations 方式なら current、そうでなければ直下の *.app
resolve_app() {
  [ -e "$1/current" ] && { printf '%s' "$1/current"; return 0; }
  set -- "$1"/*.app
  [ -d "$1" ] && printf '%s' "$1"
}

MSG=""
note() { MSG="$MSG\n$1"; }

for dir in "$BASE"/*Bridge*; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  app="$(resolve_app "$dir")"
  [ -n "$app" ] || continue

  # codesign は署名情報を stderr に出す
  info="$("$CODESIGN" -d --verbose=2 "$app" 2>&1)" || {
    note "[signed-bridge] $name: 署名を読めない"
    continue
  }

  # ad-hoc 署名には証明書が無いので期限も無い。判定できないのとは違う。
  case "$info" in *"Signature=adhoc"*) continue ;; esac

  authority="$(printf '%s' "$info" | sed -n 's/^Authority=//p' | head -1)"
  [ -n "$authority" ] || {
    note "[signed-bridge] $name: 署名の発行元を判定できない"
    continue
  }

  pem="$("$SECURITY" find-certificate -c "$authority" -p 2>/dev/null)"
  [ -n "$pem" ] || {
    note "[signed-bridge] $name: 署名した証明書がキーチェーンに無い ($authority)"
    continue
  }

  ends="$(printf '%s' "$pem" | "$OPENSSL" x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')"
  if ! printf '%s' "$pem" | "$OPENSSL" x509 -noout -checkend 0 >/dev/null 2>&1; then
    note "[signed-bridge] $name: 署名証明書が失効 ($ends) — 署名し直せないので daemon は古いまま"
    note "  証明書を更新してから対応する *-build を実行する ($authority)"
  elif ! printf '%s' "$pem" | "$OPENSSL" x509 -noout -checkend "$WARN_SECONDS" >/dev/null 2>&1; then
    note "[signed-bridge] $name: 署名証明書がまもなく失効 ($ends)"
  fi
done

[ -n "$MSG" ] && printf '%b\n' "${MSG#\\n}"

exit 0
