#!/usr/bin/env bash
# Build and sign MessageHistoryBridge.app with a stable designated requirement.
# SOURCE_DIR is injected by the Nix wrapper; the signed app generation is
# activation-time state because TCC grants cannot point into the Nix store.
set -euo pipefail

readonly SOURCE_DIR="${IMSG_HISTORY_SOURCE_DIR:?set by imsg-history-build}"
readonly IDENTITY="${IMSG_HISTORY_SIGNING_IDENTITY:?set a per-user signing identity}"
readonly BUNDLE_ID="${IMSG_HISTORY_BUNDLE_ID:?set a per-user bundle identifier}"
readonly SQLITE_INCLUDE="${IMSG_HISTORY_SQLITE_INCLUDE:?set by imsg-history-build}"
readonly SQLITE_LINK_DIR="${IMSG_HISTORY_SQLITE_LINK_DIR:?set by imsg-history-build}"
readonly BASE="$HOME/Library/Application Support/MessageHistoryBridge"
readonly TEMPORARY="$(mktemp -d "${TMPDIR:-/tmp}/imsg-history-build.XXXXXX")"
trap 'rm -rf "$TEMPORARY"' EXIT INT TERM

mkdir -p "$TEMPORARY/csqlite"
mkdir -p "$BASE"
chmod 0700 "$BASE"

cat >"$TEMPORARY/csqlite/module.modulemap" <<MODULEMAP
module CSQLite [system] {
  header "$SQLITE_INCLUDE/sqlite3.h"
  link "sqlite3"
  export *
}
MODULEMAP

if ! /usr/bin/security find-identity -v -p codesigning \
  | /usr/bin/grep -F "\"$IDENTITY\"" >/dev/null; then
  printf "imsg-history: valid unattended signing identity not found: %s\n" "$IDENTITY" >&2
  exit 77
fi

generation="$({
  openssl dgst -sha256 -r "$SOURCE_DIR/build.sh" | cut -d' ' -f1
  openssl dgst -sha256 -r "$SOURCE_DIR/message-historyd.swift" | cut -d' ' -f1
  openssl dgst -sha256 -r "$SQLITE_INCLUDE/sqlite3.h" | cut -d' ' -f1
  openssl dgst -sha256 -r "$SQLITE_LINK_DIR/libsqlite3.tbd" | cut -d' ' -f1
  command -v swiftc
  swiftc --version
  printf '%s\n' "$IDENTITY" "$BUNDLE_ID"
  /usr/bin/security find-certificate -c "$IDENTITY" -p \
    | openssl x509 -noout -fingerprint -sha256
} \
  | openssl dgst -sha256 -r | cut -d' ' -f1)"
generation_dir="$BASE/generations/$generation"
app="$generation_dir/MessageHistoryBridge.app"
staged_app="$TEMPORARY/MessageHistoryBridge.app"

if [[ -x "$app/Contents/MacOS/message-historyd" ]]; then
  mkdir -p "$BASE"
  ln -sfn "generations/$generation/MessageHistoryBridge.app" "$BASE/current"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app" >&2
  printf 'imsg-history: selected existing generation %s\n' "$generation" >&2
  exit 0
fi

mkdir -p "$staged_app/Contents/MacOS"

cat >"$staged_app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>MessageHistoryBridge</string>
  <key>CFBundleExecutable</key><string>message-historyd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF

swiftc -parse-as-library -O -I "$TEMPORARY/csqlite" -L "$SQLITE_LINK_DIR" \
  "$SOURCE_DIR/message-historyd.swift" -lsqlite3 \
  -o "$staged_app/Contents/MacOS/message-historyd"
/usr/bin/otool -L "$staged_app/Contents/MacOS/message-historyd" \
  | /usr/bin/grep -F $'\t/usr/lib/libsqlite3.dylib ' >/dev/null || {
  printf '%s\n' 'imsg-history: refusing a hardened app with a non-platform SQLite dependency' >&2
  exit 70
}
/usr/bin/codesign --force --options runtime --sign "$IDENTITY" \
  --identifier "$BUNDLE_ID" "$staged_app"

mkdir -p "$generation_dir"
[[ -e "$app" ]] || mv "$staged_app" "$app"
ln -sfn "generations/$generation/MessageHistoryBridge.app" "$BASE/current"

printf 'imsg-history: selected generation %s\n' "$generation" >&2
printf 'imsg-history: current %s\n' "$app" >&2
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app" >&2
/usr/bin/codesign -d -r- "$app" 2>&1 | tail -n 1 >&2
