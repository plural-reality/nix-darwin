@[agent-policy]

## Claude Code 履歴検索 (`ch`)

過去のセッションを探すときは `ch` コマンド（`~/.claude/scripts/claude-history.sh`）を使う。Claude Code に聞くより速い。

- `ch` — fzf でプロジェクト横断ファジー検索（386+ sessions indexed）
- `ch "keyword"` — プリフィルタ付き検索
- `ch --rebuild` — インデックス強制再構築
- `ch --list | grep X` — パイプ対応

選択すると `claude --resume <id>` がクリップボードにコピーされる。
インデックスは `~/.claude/.history-index.tsv` にキャッシュ（1時間で自動差分更新）。

## Codex CLI Invocation

Codex CLI に渡す前に `codex exec --help` を確認し、現在のCodex profile / approval policyに合う実行方法を選ぶ。read-only調査では `codex exec -c <cwd> --sandbox read-only '<prompt>'` を優先する。

@[unix-principal]
@[engineering]
@[ponytail]
@[context-compression]
@[local-installation]
@[shell-environment]
@[architectual-decision]
