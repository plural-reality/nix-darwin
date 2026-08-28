#!/usr/bin/env bash
# Build and sign ETaxWatchBridge.app with a stable designated requirement.
set -euo pipefail

readonly SOURCE_DIR="${ETAX_WATCH_SOURCE_DIR:?set by etax-watch-build}"
readonly IDENTITY="${ETAX_WATCH_SIGNING_IDENTITY:?set a per-user signing identity}"
readonly BUNDLE_ID="${ETAX_WATCH_BUNDLE_ID:?set a per-user bundle identifier}"
readonly BASE="$HOME/Library/Application Support/ETaxWatchBridge"
readonly TEMPORARY="$(mktemp -d "${TMPDIR:-/tmp}/etax-watch-build.XXXXXX")"
trap 'rm -rf "$TEMPORARY"' EXIT INT TERM

mkdir -p "$BASE/generations"
chmod 0700 "$BASE" "$BASE/generations"

if [[ "$IDENTITY" != "-" ]]; then
  /usr/bin/security find-identity -v -p codesigning \
    | /usr/bin/grep -F "\"$IDENTITY\"" >/dev/null || {
      printf 'etax-watch: valid signing identity not found: %s\n' "$IDENTITY" >&2
      exit 77
    }
fi

generation="$({
  openssl dgst -sha256 -r "$SOURCE_DIR/build.sh" | cut -d' ' -f1
  openssl dgst -sha256 -r "$SOURCE_DIR/etax-watchd.swift" | cut -d' ' -f1
  command -v swiftc
  swiftc --version
  printf '%s\n' "$IDENTITY" "$BUNDLE_ID"
  if [[ "$IDENTITY" == "-" ]]; then
    printf '%s\n' 'ad-hoc-immutable-generation'
  else
    /usr/bin/security find-certificate -c "$IDENTITY" -p \
      | openssl x509 -noout -fingerprint -sha256
  fi
} | openssl dgst -sha256 -r | cut -d' ' -f1)"
readonly GENERATION_DIR="$BASE/generations/$generation"
readonly APP="$GENERATION_DIR/ETaxWatchBridge.app"
readonly STAGED_APP="$TEMPORARY/ETaxWatchBridge.app"

if [[ -x "$APP/Contents/MacOS/etax-watchd" ]]; then
  ln -sfn "generations/$generation/ETaxWatchBridge.app" "$BASE/current"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" >&2
  printf 'etax-watch: selected existing generation %s\n' "$generation" >&2
  exit 0
fi

mkdir -p "$STAGED_APP/Contents/MacOS"
cat >"$STAGED_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>ETaxWatchBridge</string>
  <key>CFBundleExecutable</key><string>etax-watchd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF

unset SDKROOT DEVELOPER_DIR
swiftc -swift-version 5 -target "$(uname -m)-apple-macosx14.0" -parse-as-library -O \
  "$SOURCE_DIR/etax-watchd.swift" \
  -framework AppKit -framework Security -framework CryptoKit \
  -o "$STAGED_APP/Contents/MacOS/etax-watchd"
/usr/bin/codesign --force --options runtime --sign "$IDENTITY" \
  --identifier "$BUNDLE_ID" "$STAGED_APP"

mkdir -p "$GENERATION_DIR"
[[ -e "$APP" ]] || mv "$STAGED_APP" "$APP"
ln -sfn "generations/$generation/ETaxWatchBridge.app" "$BASE/current"

printf 'etax-watch: selected generation %s\n' "$generation" >&2
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" >&2
/usr/bin/codesign -d -r- "$APP" 2>&1 | tail -n 1 >&2
