# 002: Update ./apply shim to separate flake update from upstream delegation
# Ensures `nix flake update` runs before resolving .#apply, so the latest
# upstream (including new migrations) is used in a single ./apply invocation.

target="${1:-.}"
apply="$target/apply"

[[ -f "$apply" ]] || exit 0

# Guard: already updated
grep -q 'nix flake update' "$apply" && exit 0

cat > "$apply" << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
nix flake update
nix run .#apply
SHIM
chmod +x "$apply"

echo "Applied: 002-apply-shim"
