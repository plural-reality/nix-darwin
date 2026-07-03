#!/usr/bin/env bash
# Self-check:
#   bash scripts/codex-handoff.sh "smoke" >/tmp/codex-handoff.md \
#     && grep -q '^# Codex Handoff' /tmp/codex-handoff.md \
#     && grep -q 'cwd指定は大文字-C' /tmp/codex-handoff.md
set -euo pipefail

goal="${*:-TODO: goal一行を書く}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"

run_or_empty() {
  "$@" 2>/dev/null || true
}

indent() {
  sed 's/^/    /'
}

code_block() {
  local label="$1"
  shift
  printf '### %s\n\n```text\n' "$label"
  "$@" | sed 's/```/` ` `/g'
  printf '```\n\n'
}

repo_rule_paths() {
  find "$repo_root" -maxdepth 2 \( -name AGENTS.md -o -name CLAUDE.md \) -print \
    | sort \
    | sed "s#^$repo_root/#- #"
}

target_files() {
  {
    git -C "$repo_root" diff --name-only
    git -C "$repo_root" diff --cached --name-only
    git -C "$repo_root" ls-files --others --exclude-standard
  } | sort -u | sed '/^$/d'
}

package_script_candidates() {
  local package_json="$repo_root/package.json"
  [[ -f "$package_json" ]] || return 0
  jq -r '.scripts // {} | keys[] | "npm run " + .' "$package_json" 2>/dev/null || true
}

makefile_candidates() {
  local makefile="$repo_root/Makefile"
  [[ -f "$makefile" ]] || return 0
  awk -F: '/^[A-Za-z0-9][A-Za-z0-9_.-]*:([^=]|$)/ { print "make " $1 }' "$makefile" \
    | sort -u
}

flake_candidates() {
  [[ -f "$repo_root/flake.nix" ]] || return 0
  printf '%s\n' "nix flake check"
  grep -Eq 'checks|flake-parts' "$repo_root/flake.nix" \
    && printf '%s\n' "nix eval .#checks --json" \
    || true
}

verification_candidates() {
  {
    package_script_candidates
    makefile_candidates
    flake_candidates
  } | sed '/^$/d' | sort -u | sed 's/^/- /'
}

render() {
  cat <<EOF
# Codex Handoff

## cwd
\`$repo_root\`

## goal
$goal

## non-goals
- TODO: 今回触らない境界を書く

## repo rules
$(repo_rule_paths || true)

## current state

EOF
  code_block "branch" git -C "$repo_root" branch --show-current
  code_block "status --short" git -C "$repo_root" status --short
  code_block "diff --stat" git -C "$repo_root" diff --stat
  code_block "log --oneline -5" git -C "$repo_root" log --oneline -5
  cat <<EOF
## target files
$(target_files | sed 's/^/- /' || true)

## commands run
- TODO: 実行済みコマンドと重要な結果を書く

## acceptance criteria
- TODO: 完了条件を書く

## verification
$(verification_candidates || true)

## open questions
- TODO: 人間判断が必要な点だけを書く

## gotchas
- cwd指定は大文字-C(小文字-cはconfig override)
- /tmp配下は--skip-git-repo-check必須
- 軽い確認は-p fast-localプロファイル
- 長い日本語プロンプトはファイル→stdin
- 結果は--jsonで構造化受領
- 2分timeout対策はバックグラウンド化+ポーリング・30分無出力はkill
EOF
}

content="$(render)"
printf '%s\n' "$content"

if [[ -x /usr/bin/pbcopy ]]; then
  printf '%s\n' "$content" | /usr/bin/pbcopy
else
  printf '%s\n' "warning: /usr/bin/pbcopy not found; stdout only" >&2
fi
