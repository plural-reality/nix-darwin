#!/bin/sh
# evkitd.swift をコンパイル・署名し、EventKitBridge.app として install する。
# .swift を編集したら必ず実行(zwift-mode と同じく compiled binary)。
#
# canonical な「ロジック」= evkitd.swift / 「配線」= personal.nix の launchd.agents.evkitd。
# .app は build 成果物。nix store には置けない: 署名は login キーチェーンの秘密鍵を要求し、
# nix の sandbox からは到達できないため。TCC の許可は path ではなく
# (bundle ID + 証明書) に紐づくので、install 先が固定であることに依存していない。
set -eu

IDENTITY="tkgshn EventKit Bridge Signing"
BUNDLE_ID="com.tkgshn.evkitbridge"
BASE="$HOME/Library/Application Support/EventKitBridge"
APP="$BASE/EventKitBridge.app"
dir="$(cd "$(dirname "$0")" && pwd)"

# --- 署名 identity(自己署名)。無ければ作る。一度きり・冪等。 ---
# なぜ ad-hoc(codesign -s -)ではないか: ad-hoc の designated requirement は cdhash 固定になり、
# 再ビルドのたびに TCC が「別のプログラム」と見なして許可が消える。自己署名証明書なら
# DR = identifier + certificate leaf となり、ソースを変えて再ビルドしても許可が生き残る。
if ! security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  echo "evkit: 署名 identity '$IDENTITY' が無いので作成します(login キーチェーン)" >&2
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cat > "$tmp/req.cnf" <<EOF
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3
[dn]
CN = $IDENTITY
[v3]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
1.2.840.113635.100.6.1.14=critical,DER:0500
EOF
  openssl req -x509 -newkey rsa:2048 -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
    -days 7300 -nodes -config "$tmp/req.cnf" 2>/dev/null
  openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" \
    -passout pass:temp -name "$IDENTITY" 2>/dev/null
  security import "$tmp/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P temp -T /usr/bin/codesign >&2
fi

# --- build ---
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Info.plist: TCC の usage string はここから読まれる。これが無いと macOS は
# プロンプトを出さずにプロセスを拒否/終了させる(WWDC23 10052 の full/write-only 分離)。
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>EventKitBridge</string>
  <key>CFBundleExecutable</key><string>evkitd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Claude Code などのエージェントが Apple カレンダーの予定を読み書きするために使用します。</string>
  <key>NSRemindersFullAccessUsageDescription</key><string>Claude Code などのエージェントが Apple リマインダーを読み書きするために使用します。</string>
</dict></plist>
EOF

swiftc -parse-as-library -O "$dir/evkitd.swift" -o "$APP/Contents/MacOS/evkitd"
codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"

echo "evkit: installed $APP" >&2
codesign -d -r- "$APP" 2>&1 | tail -1 >&2
