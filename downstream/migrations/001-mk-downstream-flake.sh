# 001: mkSystem → mkDownstreamFlake
# Transforms flake.nix to delegate full outputs to upstream's mkDownstreamFlake.
# Also creates .envrc for direnv/nix-direnv integration.

target="${1:-.}"
flake="$target/flake.nix"

# Guard: already applied or not applicable
grep -q 'mkDownstreamFlake' "$flake" 2>/dev/null && exit 0
grep -q '\.mkSystem' "$flake" 2>/dev/null || exit 0

# Backup
cp "$flake" "$flake.pre-migrate-001"

# Extract preamble (description + inputs, everything before 'outputs')
preamble=$(awk '/^[[:space:]]*outputs[[:space:]=]/ { exit } { print }' "$flake")

# Extract mkSystem arguments via brace-matched extraction
args=$(awk '
BEGIN { depth=0; found=0 }
/\.mkSystem[[:space:]]*\{/ {
  found=1
  depth=1
  next
}
found && depth > 0 {
  for (i=1; i<=length($0); i++) {
    c = substr($0, i, 1)
    if (c == "{") depth++
    if (c == "}") {
      depth--
      if (depth == 0) {
        s = substr($0, 1, i-1)
        if (s ~ /[^[:space:]]/) print s
        found=0
        next
      }
    }
  }
  print
}
' "$flake")

if [[ -z "$args" ]]; then
  echo "Error [001]: could not extract mkSystem arguments" >&2
  mv "$flake.pre-migrate-001" "$flake"
  exit 1
fi

# Write migrated flake.nix
{
  printf '%s\n' "$preamble"
  printf '  outputs =\n'
  printf '    { nix-darwin-upstream, ... }:\n'
  printf '    nix-darwin-upstream.lib.mkDownstreamFlake {\n'
  printf '%s\n' "$args"
  printf '    };\n'
  printf '}\n'
} > "$flake"

nixfmt "$flake"

echo "Applied: 001-mk-downstream-flake"

# .envrc (companion to mkDownstreamFlake's devShells output)
if [[ ! -f "$target/.envrc" ]]; then
  echo 'use flake' > "$target/.envrc"
  echo "Created .envrc"
fi
