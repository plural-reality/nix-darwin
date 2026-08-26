#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
settings_root="$(mktemp -d)"
settings_file="$settings_root/settings.local.json"
trap 'rm -rf "$settings_root"' EXIT INT TERM

printf '%s\n' '{"env":{}}' > "$settings_file"
/bin/chmod 644 "$settings_file"

SETTINGS="$settings_file" bash -c 'source "$1"; ensure_settings_mode' _ "$script_dir/scrapbox-sid-refresh.sh"

test "$(stat -f '%Lp' "$settings_file")" = "600"

symlink_target="$settings_root/symlink-target.json"
symlink_settings="$settings_root/symlink-settings.json"
printf '%s\n' '{"env":{}}' > "$symlink_target"
/bin/chmod 640 "$symlink_target"
ln -s "$symlink_target" "$symlink_settings"
if SETTINGS="$symlink_settings" bash -c 'source "$1"; ensure_settings_mode' _ "$script_dir/scrapbox-sid-refresh.sh" >/dev/null 2>&1; then
  printf '%s\n' 'expected settings symlink rejection' >&2
  exit 1
fi
test "$(stat -f '%Lp' "$symlink_target")" = "640"

printf '%s\n' 'scrapbox-sid-refresh permissions: ok'
