# 002: Decouple ./apply shim from local lock
# Uses github: reference so the shim always fetches the latest upstream.
# Eliminates chicken-and-egg: shim never needs updating again.

target="${1:-.}"
apply="$target/apply"

[[ -f "$apply" ]] || exit 0

# Guard: already decoupled
grep -q 'github:plural-reality/nix-darwin#apply' "$apply" && exit 0

cat > "$apply" << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec nix run "github:plural-reality/nix-darwin#apply"
SHIM
chmod +x "$apply"

echo "Applied: 002-apply-shim"
