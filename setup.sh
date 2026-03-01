# setup.sh — Pure IO: prompts + substitution + side effects
# Templates are injected via $TEMPLATES (Nix store path, set by writeShellApplication)

# --- Helper ---
prompt_with_default() {
  local prompt_text="$1"
  local default="$2"
  local result
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$prompt_text" "$default" >&2
  else
    printf '%s: ' "$prompt_text" >&2
  fi
  read -r result
  echo "${result:-$default}"
}

substitute() {
  sed -e "s|@USERNAME@|$username|g" \
      -e "s|@HOSTNAME@|$hostname_val|g" \
      -e "s|@GIT_NAME@|$git_name|g" \
      -e "s|@GIT_EMAIL@|$git_email|g" \
      -e "s|@AGE_PUBLIC_KEY@|$age_public_key|g" \
      -e "s|@OPENROUTER_KEY@|$openrouter_key|g" \
      -e "s|@GEMINI_KEY@|$gemini_key|g" \
      -e "s|@ANTHROPIC_KEY@|$anthropic_key|g" \
      "$1"
}

# --- 1. Gather user info ---
echo "=== nix-darwin team setup ==="
echo ""

default_username="$(whoami)"
default_hostname="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
default_git_name="$(git config --global user.name 2>/dev/null || echo '')"
default_git_email="$(git config --global user.email 2>/dev/null || echo '')"

username="$(prompt_with_default 'Username' "$default_username")"
hostname_val="$(prompt_with_default 'Hostname' "$default_hostname")"
git_name="$(prompt_with_default 'Git name' "$default_git_name")"
git_email="$(prompt_with_default 'Git email' "$default_git_email")"
target_dir="$(prompt_with_default 'Target directory' "/private/etc/nix-darwin")"

# --- 2. Age key ---
age_key_dir="$HOME/.config/sops/age"
age_key_file="$age_key_dir/keys.txt"

if [[ ! -f "$age_key_file" ]]; then
  echo ""
  echo "Generating age key pair..."
  mkdir -p "$age_key_dir"
  age-keygen -o "$age_key_file"
fi

age_public_key="$(age-keygen -y "$age_key_file")"
echo ""
echo "Age public key: $age_public_key"
echo "This will be used to encrypt secrets with sops. Keep the private key safe!"
echo "Private key file: $age_key_file"

# --- 3. API keys (optional) ---
echo ""
echo "Enter API keys (leave blank to skip):"
openrouter_key="$(prompt_with_default 'OpenRouter API key' '')"
gemini_key="$(prompt_with_default 'Gemini API key' '')"
anthropic_key="$(prompt_with_default 'Anthropic API key' '')"

# --- 4. Guard against overwriting ---
if [[ -d "$target_dir/.git" ]]; then
  echo ""
  echo "Error: $target_dir already contains a git repository." >&2
  echo "Remove it or choose a different directory." >&2
  exit 1
fi

# --- 5. Generate files from templates ---
if [[ ! -d "$target_dir" ]]; then
  sudo mkdir -p "$target_dir"
  sudo chown "$(whoami)" "$target_dir"
fi

substitute "$TEMPLATES/flake.nix.template" > "$target_dir/flake.nix"
substitute "$TEMPLATES/sops.yaml.template" > "$target_dir/.sops.yaml"
substitute "$TEMPLATES/secrets.yaml.template" > "$target_dir/secrets.yaml"
cp "$TEMPLATES/gitignore" "$target_dir/.gitignore"
cp "$TEMPLATES/apply" "$target_dir/apply"
chmod +x "$target_dir/apply"

SOPS_AGE_KEY_FILE="$age_key_file" sops --config "$target_dir/.sops.yaml" --encrypt --in-place "$target_dir/secrets.yaml"

# --- 6. Git init ---
git -C "$target_dir" init
git -C "$target_dir" add -A
git -C "$target_dir" commit -m "Initial nix-darwin configuration"

echo ""
echo "=== Setup complete ==="
echo "Directory: $target_dir"
echo ""
echo "Next steps:"
echo "  cd $target_dir"
echo "  ./apply"
