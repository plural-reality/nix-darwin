#!/usr/bin/env bash
set -euo pipefail

case "$#" in
  2) ;;
  *)
    printf '%s\n' 'usage: test-codex-code-mode-launcher-contract.sh <home-files-root> <activation-script>' >&2
    exit 64
    ;;
esac

readonly home_files="$1"
readonly codex_target="$(readlink -f "$home_files/.local/bin/codex")"
readonly code_mode_host_target="$(readlink -f "$home_files/.local/bin/codex-code-mode-host")"

test -x "$codex_target"
test -x "$code_mode_host_target"
printf '%s\n' "$codex_target" | grep -Eq '^/nix/store/[^/]+-codex-[^/]+/bin/codex$'
printf '%s\n' "$code_mode_host_target" | grep -Eq '^/nix/store/[^/]+-codex-[^/]+/bin/codex-code-mode-host$'

case "$#" in
  2)
    readonly activation_script="$2"
    readonly fixture="$(mktemp -d)"
    readonly fragment="$fixture/preserve-links.sh"
    readonly exact_home="$fixture/exact"
    readonly absent_home="$fixture/absent"
    readonly codex_mismatch_home="$fixture/codex-mismatch"
    readonly code_mode_mismatch_home="$fixture/code-mode-mismatch"
    readonly claude_mismatch_home="$fixture/claude-mismatch"
    readonly regular_archive_home="$fixture/regular-archive"
    trap '/bin/rm -rf "$fixture"' EXIT

    /usr/bin/awk '
      /^readonly archive_root=/ { capture = 1 }
      /^_iNote "Activating %s" "checkLinkTargets"/ { capture = 0 }
      capture { print }
    ' "$activation_script" > "$fragment"
    test -s "$fragment"

    /bin/mkdir -p "$exact_home/.local/bin" "$exact_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$exact_home/.codex/packages/standalone/current/bin/codex" "$exact_home/.local/bin/codex"
    /bin/ln -s "$exact_home/.codex/packages/standalone/current/bin/codex" "$exact_home/.local/state/home-manager-adoption/agent-cli-links/codex-standalone-legacy"
    /bin/ln -s "$exact_home/.codex/packages/standalone/current/bin/codex-code-mode-host" "$exact_home/.local/bin/codex-code-mode-host"
    /bin/ln -s "$exact_home/.codex/packages/standalone/current/bin/codex-code-mode-host" "$exact_home/.local/state/home-manager-adoption/agent-cli-links/codex-code-mode-host-standalone-legacy"
    /bin/ln -s "$exact_home/.local/share/claude/versions/2.1.246/claude" "$exact_home/.local/bin/claude"
    /bin/ln -s "$exact_home/.local/share/claude/versions/2.1.246/claude" "$exact_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy"
    HOME="$exact_home" /bin/bash "$fragment"

    test ! -e "$exact_home/.local/bin/codex" && test ! -L "$exact_home/.local/bin/codex"
    test ! -e "$exact_home/.local/bin/codex-code-mode-host" && test ! -L "$exact_home/.local/bin/codex-code-mode-host"
    test ! -e "$exact_home/.local/bin/claude" && test ! -L "$exact_home/.local/bin/claude"
    test "$(readlink "$exact_home/.local/state/home-manager-adoption/agent-cli-links/codex-standalone-legacy")" = "$exact_home/.codex/packages/standalone/current/bin/codex"
    test "$(readlink "$exact_home/.local/state/home-manager-adoption/agent-cli-links/codex-code-mode-host-standalone-legacy")" = "$exact_home/.codex/packages/standalone/current/bin/codex-code-mode-host"
    test "$(readlink "$exact_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy")" = "$exact_home/.local/share/claude/versions/2.1.246/claude"

    /bin/mkdir -p "$absent_home/.local/bin"
    /bin/ln -s "$absent_home/.codex/packages/standalone/current/bin/codex" "$absent_home/.local/bin/codex"
    /bin/ln -s "$absent_home/.codex/packages/standalone/current/bin/codex-code-mode-host" "$absent_home/.local/bin/codex-code-mode-host"
    /bin/ln -s "$absent_home/.local/share/claude/versions/2.1.246/claude" "$absent_home/.local/bin/claude"
    HOME="$absent_home" /bin/bash "$fragment"

    test ! -e "$absent_home/.local/bin/codex" && test ! -L "$absent_home/.local/bin/codex"
    test ! -e "$absent_home/.local/bin/codex-code-mode-host" && test ! -L "$absent_home/.local/bin/codex-code-mode-host"
    test ! -e "$absent_home/.local/bin/claude" && test ! -L "$absent_home/.local/bin/claude"
    test "$(readlink "$absent_home/.local/state/home-manager-adoption/agent-cli-links/codex-standalone-legacy")" = "$absent_home/.codex/packages/standalone/current/bin/codex"
    test "$(readlink "$absent_home/.local/state/home-manager-adoption/agent-cli-links/codex-code-mode-host-standalone-legacy")" = "$absent_home/.codex/packages/standalone/current/bin/codex-code-mode-host"
    test "$(readlink "$absent_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy")" = "$absent_home/.local/share/claude/versions/2.1.246/claude"

    /bin/mkdir -p "$codex_mismatch_home/.local/bin" "$codex_mismatch_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$codex_mismatch_home/.codex/packages/standalone/current/bin/codex" "$codex_mismatch_home/.local/bin/codex"
    /bin/ln -s "$codex_mismatch_home/unmanaged-codex" "$codex_mismatch_home/.local/state/home-manager-adoption/agent-cli-links/codex-standalone-legacy"
    ! /usr/bin/env HOME="$codex_mismatch_home" /bin/bash "$fragment" >/dev/null 2>&1
    test -L "$codex_mismatch_home/.local/bin/codex"
    test "$(readlink "$codex_mismatch_home/.local/bin/codex")" = "$codex_mismatch_home/.codex/packages/standalone/current/bin/codex"

    /bin/mkdir -p "$code_mode_mismatch_home/.local/bin" "$code_mode_mismatch_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$code_mode_mismatch_home/.codex/packages/standalone/current/bin/codex-code-mode-host" "$code_mode_mismatch_home/.local/bin/codex-code-mode-host"
    /bin/ln -s "$code_mode_mismatch_home/unmanaged-code-mode-host" "$code_mode_mismatch_home/.local/state/home-manager-adoption/agent-cli-links/codex-code-mode-host-standalone-legacy"
    ! /usr/bin/env HOME="$code_mode_mismatch_home" /bin/bash "$fragment" >/dev/null 2>&1
    test -L "$code_mode_mismatch_home/.local/bin/codex-code-mode-host"
    test "$(readlink "$code_mode_mismatch_home/.local/bin/codex-code-mode-host")" = "$code_mode_mismatch_home/.codex/packages/standalone/current/bin/codex-code-mode-host"

    /bin/mkdir -p "$claude_mismatch_home/.local/bin" "$claude_mismatch_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$claude_mismatch_home/.local/share/claude/versions/2.1.246/claude" "$claude_mismatch_home/.local/bin/claude"
    /bin/ln -s "$claude_mismatch_home/.local/share/claude/versions/2.1.245/claude" "$claude_mismatch_home/.local/state/home-manager-adoption/agent-cli-links/claude-updater-legacy"
    ! /usr/bin/env HOME="$claude_mismatch_home" /bin/bash "$fragment" >/dev/null 2>&1
    test -L "$claude_mismatch_home/.local/bin/claude"
    test "$(readlink "$claude_mismatch_home/.local/bin/claude")" = "$claude_mismatch_home/.local/share/claude/versions/2.1.246/claude"

    /bin/mkdir -p "$regular_archive_home/.local/bin" "$regular_archive_home/.local/state/home-manager-adoption/agent-cli-links"
    /bin/ln -s "$regular_archive_home/.codex/packages/standalone/current/bin/codex" "$regular_archive_home/.local/bin/codex"
    printf '%s\n' 'unmanaged archive' > "$regular_archive_home/.local/state/home-manager-adoption/agent-cli-links/codex-standalone-legacy"
    ! /usr/bin/env HOME="$regular_archive_home" /bin/bash "$fragment" >/dev/null 2>&1
    test -L "$regular_archive_home/.local/bin/codex"
    test -f "$regular_archive_home/.local/state/home-manager-adoption/agent-cli-links/codex-standalone-legacy"

    ;;
  *) ;;
esac

printf '%s\n' 'codex-code-mode-launcher-contract: ok'
