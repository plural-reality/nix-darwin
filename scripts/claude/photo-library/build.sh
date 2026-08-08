#!/usr/bin/env bash
# Build and sign PhotoLibraryBridge.app with a stable designated requirement.
set -euo pipefail

readonly SOURCE_DIR="${PHOTO_LIBRARY_SOURCE_DIR:?set by photo-library-build}"
readonly IDENTITY="${PHOTO_LIBRARY_SIGNING_IDENTITY:?set a per-user signing identity}"
readonly BUNDLE_ID="${PHOTO_LIBRARY_BUNDLE_ID:?set a per-user bundle identifier}"
readonly BASE="$HOME/Library/Application Support/PhotoLibraryBridge"
readonly TEMPORARY="$(mktemp -d "${TMPDIR:-/tmp}/photo-library-build.XXXXXX")"
trap 'rm -rf "$TEMPORARY"' EXIT INT TERM

mkdir -p "$BASE/generations" "$BASE/exports"
chmod 0700 "$BASE" "$BASE/exports"

/usr/bin/security find-identity -v -p codesigning \
  | /usr/bin/grep -F "\"$IDENTITY\"" >/dev/null || {
  printf 'photo-library: valid signing identity not found: %s\n' "$IDENTITY" >&2
  exit 77
}

generation="$({
  openssl dgst -sha256 -r "$SOURCE_DIR/build.sh" | cut -d' ' -f1
  openssl dgst -sha256 -r "$SOURCE_DIR/photo-libraryd.swift" | cut -d' ' -f1
  command -v swiftc
  swiftc --version
  printf '%s\n' "$IDENTITY" "$BUNDLE_ID"
  /usr/bin/security find-certificate -c "$IDENTITY" -p \
    | openssl x509 -noout -fingerprint -sha256
} | openssl dgst -sha256 -r | cut -d' ' -f1)"
readonly GENERATION_DIR="$BASE/generations/$generation"
readonly APP="$GENERATION_DIR/PhotoLibraryBridge.app"
readonly STAGED_APP="$TEMPORARY/PhotoLibraryBridge.app"

if [[ -x "$APP/Contents/MacOS/photo-libraryd" ]]; then
  ln -sfn "generations/$generation/PhotoLibraryBridge.app" "$BASE/current"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" >&2
  printf 'photo-library: selected existing generation %s\n' "$generation" >&2
  exit 0
fi

mkdir -p "$STAGED_APP/Contents/MacOS"
cat >"$STAGED_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>PhotoLibraryBridge</string>
  <key>CFBundleExecutable</key><string>photo-libraryd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPhotoLibraryUsageDescription</key><string>新しく追加された名刺写真を検出し、人物ページ作成のために読み取ります。</string>
</dict></plist>
EOF

swiftc -swift-version 5 -target "$(uname -m)-apple-macosx14.0" -parse-as-library -O \
  "$SOURCE_DIR/photo-libraryd.swift" \
  -framework AppKit -framework Photos -framework Vision -framework CryptoKit \
  -o "$STAGED_APP/Contents/MacOS/photo-libraryd"
cat >"$TEMPORARY/entitlements.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.personal-information.photos-library</key><true/>
</dict></plist>
EOF
/usr/bin/codesign --force --options runtime --sign "$IDENTITY" \
  --identifier "$BUNDLE_ID" --entitlements "$TEMPORARY/entitlements.plist" "$STAGED_APP"

mkdir -p "$GENERATION_DIR"
[[ -e "$APP" ]] || mv "$STAGED_APP" "$APP"
ln -sfn "generations/$generation/PhotoLibraryBridge.app" "$BASE/current"

printf 'photo-library: selected generation %s\n' "$generation" >&2
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" >&2
/usr/bin/codesign -d -r- "$APP" 2>&1 | tail -n 1 >&2
