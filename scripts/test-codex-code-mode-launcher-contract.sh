#!/usr/bin/env bash
set -euo pipefail

case "$#" in
  3) ;;
  *)
    printf '%s\n' 'usage: test-codex-code-mode-launcher-contract.sh <home-files-root> <home-path> <activation-script>' >&2
    exit 64
    ;;
esac

readonly home_files="$1"
readonly home_path="$2"
readonly activation_script="$3"
readonly codex_target="$(readlink -f "$home_path/bin/codex")"
readonly code_mode_host_target="$(readlink -f "$home_path/bin/codex-code-mode-host")"
readonly managed_config_paths="$(/usr/bin/grep -Eo '/nix/store/[^[:space:]]+-codex-managed-config\.json' "$activation_script" | /usr/bin/sort -u)"
readonly session_vars="$home_path/etc/profile.d/hm-session-vars.sh"
readonly fish_session_vars="$home_path/etc/profile.d/hm-session-vars.fish"

test "$(printf '%s\n' "$managed_config_paths" | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')" = 1
readonly managed_config="$managed_config_paths"

test -x "$codex_target"
test -x "$code_mode_host_target"
test -f "$managed_config"
test -f "$session_vars"
test -f "$fish_session_vars"
jq -e '.features.code_mode == false' "$managed_config" >/dev/null
printf '%s\n' "$codex_target" | grep -Eq '^/nix/store/[^/]+-codex-[^/]+/bin/codex$'
printf '%s\n' "$code_mode_host_target" | grep -Eq '^/nix/store/[^/]+-codex-[^/]+/bin/codex-code-mode-host$'
! test -e "$home_files/.local/bin/codex" && ! test -L "$home_files/.local/bin/codex"
! test -e "$home_files/.local/bin/codex-code-mode-host" && ! test -L "$home_files/.local/bin/codex-code-mode-host"
! test -e "$home_files/.config/fish/functions/codex.fish" && ! test -L "$home_files/.config/fish/functions/codex.fish"
! /usr/bin/grep -Fq '.codex/packages/standalone' "$activation_script"
/usr/bin/grep -Eq '^export PATH="[^"]+/\.nix-profile/bin:[^"]+/\.local/bin\$\{PATH:\+:\}\$PATH"$' "$session_vars"
/usr/bin/grep -Eq "^set -gx PATH '[^']+/\.nix-profile/bin:[^']+/\.local/bin'" "$fish_session_vars"

case "$#" in
  3)
    readonly fixture="$(mktemp -d)"
    readonly fragment="$fixture/preserve-links.sh"
    readonly codex_fish_fragment="$fixture/retire-codex-fish-wrapper.sh"
    readonly exact_home="$fixture/exact"
    readonly claude_mismatch_home="$fixture/claude-mismatch"
    readonly codex_fish_home="$fixture/codex-fish"
    readonly codex_fish_mismatch_home="$fixture/codex-fish-mismatch"
    trap '/bin/rm -rf "$fixture"' EXIT

    /usr/bin/awk '
      /^readonly archive_root=/ { capture = 1 }
      /^_iNote "Activating %s" "retireLegacyCodexFishWrapper"/ { capture = 0 }
      /^_iNote "Activating %s" "checkLinkTargets"/ { capture = 0 }
      capture { print }
    ' "$activation_script" > "$fragment"
    test -s "$fragment"

    /usr/bin/awk '
      /^_iNote "Activating %s" "retireLegacyCodexFishWrapper"/ { capture = 1; next }
      capture && /^_iNote "Activating %s"/ { exit }
      capture { print }
    ' "$activation_script" > "$codex_fish_fragment"
    test -s "$codex_fish_fragment"

    /bin/mkdir -p "$exact_home/.local/bin" "$exact_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$exact_home/.local/share/claude/versions/2.1.246/claude" "$exact_home/.local/bin/claude"
    /bin/ln -s "$exact_home/.local/share/claude/versions/2.1.246/claude" "$exact_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy"
    HOME="$exact_home" /bin/bash "$fragment"

    test ! -e "$exact_home/.local/bin/claude" && test ! -L "$exact_home/.local/bin/claude"
    test "$(readlink "$exact_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy")" = "$exact_home/.local/share/claude/versions/2.1.246/claude"

    /bin/mkdir -p "$claude_mismatch_home/.local/bin" "$claude_mismatch_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$claude_mismatch_home/.local/share/claude/versions/2.1.246/claude" "$claude_mismatch_home/.local/bin/claude"
    /bin/ln -s "$claude_mismatch_home/.local/share/claude/versions/2.1.245/claude" "$claude_mismatch_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy"
    ! /usr/bin/env HOME="$claude_mismatch_home" /bin/bash "$fragment" >/dev/null 2>&1
    test -L "$claude_mismatch_home/.local/bin/claude"
    test "$(readlink "$claude_mismatch_home/.local/bin/claude")" = "$claude_mismatch_home/.local/share/claude/versions/2.1.246/claude"

    /bin/mkdir -p "$codex_fish_home/.config/fish/functions"
    cat > "$codex_fish_home/.config/fish/functions/codex.fish" <<'EOF'
function codex --wraps codex --description 'OpenAI Codex CLI 0.144.6 from Nix store'
    /nix/store/gvc53wdyamf067sxlh7qpf9xhw8hm3cr-codex-0.144.6/bin/codex $argv
end
EOF
    HOME="$codex_fish_home" /bin/bash "$codex_fish_fragment"
    test ! -e "$codex_fish_home/.config/fish/functions/codex.fish"
    test -f "$codex_fish_home/.local/state/home-manager-adoption/agent-cli-links/codex-fish-wrapper-0.144.6"

    /bin/mkdir -p "$codex_fish_mismatch_home/.config/fish/functions"
    cat > "$codex_fish_mismatch_home/.config/fish/functions/codex.fish" <<'EOF'
function codex
    echo user-defined
end
EOF
    ! /usr/bin/env HOME="$codex_fish_mismatch_home" /bin/bash "$codex_fish_fragment" >/dev/null 2>&1
    test -f "$codex_fish_mismatch_home/.config/fish/functions/codex.fish"

    ;;
  *) ;;
esac

printf '%s\n' 'codex-code-mode-launcher-contract: ok'
