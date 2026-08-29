## 言語

常に日本語で返答してください。コード・コミットメッセージ・識別子・ログなど、技術的に英語が適切なものは英語のままで構いません。

独立したread-heavy subtaskが二つ以上で実時間を短縮する時だけチームを組んでください。小さい作業、write-heavy作業、単一境界の作業は単独で進めます。

## Routing Table

| 条件 | canonical source / skill |
|---|---|
| Project-specific context | 対象repoの `CLAUDE.md`。存在しなければ `AGENTS.md` を互換入力として使う。 |
| 曖昧で大きい設計・実装・デプロイ | `clarify-and-build`。小さく明確な変更には適用しない。 |
| コードの作成・レビュー | `functional-style` と `ponytail`。repo固有規約を優先する。 |
| Nix、Home Manager、ツール導入 | `nix` と対象repoのrunbook。生成済みruntimeは編集しない。 |
| MCP、plugin、agent tool の設計・変更 | `agent-tooling-safety`。 |
| Scrapboxの読書き | `scrapbox-context` と `save-to-scrapbox`。 |
| ブラウザの読取り・視覚確認・対話 | `browser-automation`。 |
| 本人の予定・空き時間 | `apple-calendar`。リマインダーの振り分けは `remind-or-schedule`。 |
| 人へのメール・Beeper・iMessage・DM | 対応する送信skill。本文承認の不変条件は下記に従う。 |
| 人脈活用・紹介依頼・相談メッセージ | `ask-network`。 |
| 返信の収集・統合・元の相手への返信作成 | `collect-and-reply`。 |
| 「さっき／以前／見た／読んだ／やった」など本人の過去活動 | `coast-cli-skill`。候補はliveの正本で照合する。 |

## Claude / Codex boundary

- Claudeは設計・要件の曖昧さ解消・候補比較・fresh-context review、Codexはrepo実装・テスト・CI/log triage・機械的変更に向く。役割は作業の失敗モードで決め、ブランドで決めない。
- 同じ会話で生成と承認を兼ねない。高影響な変更だけ、別のモデルまたは実測で反証・回帰を確認する。
- Handoffには `cwd`、goal、non-goals、canonical source、current state、acceptance criteria、verification、open questionsだけを渡す。会話断片を丸ごと渡さない。

## Shared Agent Skills And Memory

- 共有skillの正本は `prompt/claude-code/skills/<name>/`。runtimeコピーを直接編集しない。
- 共有memoryの正本は Claude auto-memory の `MEMORY.md` index とtopic file。非自明な作業ではindexから関連topicだけを読む。
- memoryの更新は `self-learn` skillだけを使う。`~/.codex/memories` を共有memoryとして読書きしない。

## Shell boundary

- ユーザーがターミナルに貼るコマンドはfish構文、エージェント自身の実行はzsh/POSIX構文を使う。
- GUIを明示されない限り、CLI/APIで同等に実行・検証できる作業はCLI/APIを使う。

@[agent-operations]
