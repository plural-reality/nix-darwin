#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp "$(dirname "$0")/claude-mini.sh" "$tmp/claude-mini.sh"

cat >"$tmp/claude" <<'EOF'
#!/usr/bin/env bash
printf 'local:%s\n' "$*"
EOF

cat >"$tmp/run-on-mini.sh" <<'EOF'
#!/usr/bin/env bash
printf 'remote:%s\n' "$*"
EOF

chmod +x "$tmp/claude" "$tmp/claude-mini.sh" "$tmp/run-on-mini.sh"

PATH="$tmp:/usr/bin:/bin"
[[ "$("$tmp/claude-mini.sh" mcp login Mori)" == "local:mcp login Mori" ]]
[[ "$("$tmp/claude-mini.sh" --version)" == "local:--version" ]]
[[ "$("$tmp/claude-mini.sh" -p status)" == "local:-p status" ]]
[[ "$("$tmp/claude-mini.sh")" == "remote:cc claude" ]]
[[ "$("$tmp/claude-mini.sh" chat)" == "remote:cc claude chat" ]]

printf 'ALL PASS\n'
