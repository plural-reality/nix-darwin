# 002: Delegate ./apply to the downstream flake
# Keeps activation on the same nix-darwin-upstream input that the system uses.

target="${1:-.}"
apply="$target/apply"

[[ -f "$apply" ]] || exit 0

# Guard: already delegated
grep -q 'nix run .#apply' "$apply" && exit 0

cat > "$apply" << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec nix run .#apply
SHIM
chmod +x "$apply"

echo "Applied: 002-apply-shim"
