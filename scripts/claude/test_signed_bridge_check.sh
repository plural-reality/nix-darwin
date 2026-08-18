#!/usr/bin/env bash
# signed-bridge-check.sh の runnable check。
# keychain も実機の app も触らない。codesign/security/openssl を差し替えて、
# 「どの状態を報告し、どの状態で黙るか」だけを見る(期限判定そのものは openssl の仕事)。
set -euo pipefail

CHECK="$(cd "$(dirname "$0")" && pwd)/signed-bridge-check.sh"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

BASE="$TEMP/base"
for name in ExpiredBridge ValidBridge AdhocBridge UnknownBridge; do
  mkdir -p "$BASE/$name/$name.app"
done

# app 名から署名情報を返す。codesign は stderr に出すので合わせる。
cat > "$TEMP/codesign" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *ExpiredBridge*) echo "Authority=expired-ca" >&2 ;;
  *ValidBridge*)   echo "Authority=valid-ca" >&2 ;;
  *AdhocBridge*)   echo "Signature=adhoc" >&2 ;;
  *)               echo "Format=app bundle" >&2 ;;   # Authority 無し・adhoc でもない
esac
STUB

# CN をそのまま PEM 代わりに返す(中身は openssl スタブが解釈する)。
cat > "$TEMP/security" <<'STUB'
#!/usr/bin/env bash
printf 'CERT:%s\n' "$3"
STUB

# checkend: expired-ca は常に期限切れ、valid-ca は 10 年先まで有効とみなす。
cat > "$TEMP/openssl" <<'STUB'
#!/usr/bin/env bash
cert="$(cat)"
args="$*"   # ${*##...} は各引数へ個別適用されるので、一度連結してから剥がす
case "$args" in
  *-enddate*) printf 'notAfter=%s expiry\n' "${cert#CERT:}"; exit 0 ;;
esac
window="${args##*-checkend }"
case "$cert" in
  *expired-ca*) exit 1 ;;
  *valid-ca*)   [ "$window" -lt 315360000 ] ;;
esac
STUB
chmod +x "$TEMP/codesign" "$TEMP/security" "$TEMP/openssl"

run() {  # run [warn_seconds]
  (
    export SIGNED_BRIDGE_BASE="$BASE" SIGNED_BRIDGE_CODESIGN="$TEMP/codesign" \
           SIGNED_BRIDGE_SECURITY="$TEMP/security" SIGNED_BRIDGE_OPENSSL="$TEMP/openssl"
    if [ -n "${1:-}" ]; then export SIGNED_BRIDGE_WARN_SECONDS="$1"; fi
    bash "$CHECK"
  )
}

out="$(run)"
fail() { printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "$2" >&2; exit 1; }

case "$out" in *"ExpiredBridge: 署名証明書が失効"*) ;; *) fail "失効を報告していない" "$out" ;; esac
case "$out" in *"UnknownBridge: 署名の発行元を判定できない"*) ;; *) fail "判定不能を報告していない" "$out" ;; esac
# 有効な証明書と ad-hoc は黙る。ad-hoc に証明書は無いので「失効」でも「不明」でもない。
case "$out" in *ValidBridge*) fail "有効な証明書を報告している" "$out" ;; esac
case "$out" in *AdhocBridge*) fail "ad-hoc を報告している" "$out" ;; esac

# 警告窓を 10 年より広げれば、有効な証明書も「まもなく失効」として出る
wide="$(run 999999999)"
case "$wide" in *"ValidBridge: 署名証明書がまもなく失効"*) ;; *) fail "警告窓が効いていない" "$wide" ;; esac

echo "signed-bridge-check tests: passed"
