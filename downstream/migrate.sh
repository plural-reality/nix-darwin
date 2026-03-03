# migrate.sh — Transform downstream flake.nix from mkSystem to mkDownstreamFlake
# Usage: nix run github:plural-reality/nix-darwin#migrate [target-dir]

target="${1:-.}"
flake="$target/flake.nix"

# --- Guards ---
if [[ ! -f "$flake" ]]; then
  echo "Error: $flake not found" >&2
  exit 1
fi

if grep -q 'mkDownstreamFlake' "$flake"; then
  echo "Already using mkDownstreamFlake."
  [[ -f "$target/.envrc" ]] || { echo 'use flake' > "$target/.envrc"; echo "Created .envrc"; }
  exit 0
fi

if ! grep -q '\.mkSystem' "$flake"; then
  echo "Error: no mkSystem call found in $flake" >&2
  exit 1
fi

# --- Backup ---
cp "$flake" "$flake.pre-migrate"

# --- Extract preamble (description + inputs, everything before 'outputs') ---
preamble=$(awk '/^[[:space:]]*outputs[[:space:]=]/ { exit } { print }' "$flake")

# --- Extract mkSystem arguments via brace-matched extraction ---
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
  echo "Error: could not extract mkSystem arguments" >&2
  mv "$flake.pre-migrate" "$flake"
  exit 1
fi

# --- Write migrated flake.nix ---
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

# --- .envrc ---
if [[ ! -f "$target/.envrc" ]]; then
  echo 'use flake' > "$target/.envrc"
  echo "Created .envrc"
fi

echo ""
echo "Migrated to mkDownstreamFlake"
echo "Backup: $flake.pre-migrate"
echo ""
echo "Next: cd $target && ./apply"
