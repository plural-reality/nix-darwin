#!/usr/bin/env bash
#
# SessionStart hook — 新規プロジェクトで /init を促す。
#
# 抽象:  f(stdin: SessionStart JSON) -> stdout: (additionalContext JSON | ∅)
#        判定材料は .cwd のみ。ファイルシステムを変更しない read-only な純粋フィルタ。
#
# 発火条件 (すべて真のときだけ context を emit する):
#   1. cwd が取得できる
#   2. cwd が git 管理下である         … 「プロジェクト」であることの代理シグナル
#   3. cwd に CLAUDE.md も AGENTS.md も存在しない … まだ /init されていない (AGENTS.md は Codex 互換ソース)
# それ以外 (CLAUDE.md/AGENTS.md 既存 / 非 git ディレクトリ / cwd 不明 / 不正 JSON) は
# 無音のまま exit 0。
#   → 冪等:  一度 /init すれば二度と促さない。既存プロジェクトでは完全に無風。
#
# 注意:  フックは slash command を直接実行できない。ここでできるのは
#        「/init を実行せよ」という指示を additionalContext として
#        セッションに注入することだけ。実際に /init を走らせるのは Claude 本体。

set -uo pipefail

readonly input="$(cat)"
readonly cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"

# ガード節を && 連鎖で式化。1 つでも偽なら無音で抜ける。
{ [ -n "$cwd" ] && [ -e "$cwd/.git" ] && [ ! -f "$cwd/CLAUDE.md" ] && [ ! -f "$cwd/AGENTS.md" ]; } || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: "このプロジェクトには CLAUDE.md がまだありません(git 管理下の新規プロジェクトと判定)。ユーザーの最初の依頼に取りかかる前に、まず /init を実行してコードベースを分析し CLAUDE.md を生成することを提案・実行してください。ここがプロジェクトルートでない場合や、ユーザーが明確に別の作業を指示している場合はスキップして構いません。"
  }
}' 2>/dev/null || true

exit 0
