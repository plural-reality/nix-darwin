# migrate.sh — Run all pending migrations in order
# MIGRATIONS is injected as a Nix store path by writeShellApplication.

target="${1:-.}"

for script in "$MIGRATIONS"/*.sh; do
  [[ -f "$script" ]] || continue
  bash "$script" "$target"
done
