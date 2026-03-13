常に、並行でこなせる作業は、チームを組んで最大効率で作業してください。

## Routing Table

| Context | Reference |
|---------|-----------|
| Project-specific context | Each repo's `CLAUDE.md` |
| 人脈活用・紹介依頼・相談メッセージ | `/ask-network` |
| 返信の収集・統合・元の相手への返信作成 | `/collect-and-reply` |

## Claude Code 履歴検索 (`ch`)

過去のセッションを探すときは `ch` コマンド（`~/.claude/scripts/claude-history.sh`）を使う。Claude Code に聞くより速い。

- `ch` — fzf でプロジェクト横断ファジー検索（386+ sessions indexed）
- `ch "keyword"` — プリフィルタ付き検索
- `ch --rebuild` — インデックス強制再構築
- `ch --list | grep X` — パイプ対応

選択すると `claude --resume <id>` がクリップボードにコピーされる。
インデックスは `~/.claude/.history-index.tsv` にキャッシュ（1時間で自動差分更新）。

@[unix-principal]
@[engineering]
@[context-compression]
@[local-installation]
