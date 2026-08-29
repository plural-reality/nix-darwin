## 言語

常に日本語で返答してください。コード・コミットメッセージ・識別子・ログなど、技術的に英語が適切なものは英語のままで構いません。

## Codexタスク名

- タスク名は一覧用の派生表示であり、進捗・確認要否・完了根拠の正本ではない。
- 状態は `⬜` / `⌛️` / `☑️` / `⏹️` と、本人の対応を求める `🚨` を使う。`⏳` は使わない。
- 次の作業を進められる時だけ `⌛️ {主題}`、本人の判断・認証・確認・操作が必要なら `🚨 {主題}`、外部応答待ちは `⌛️ {主題}（{相手}の返信待ち）` とする。canonical readbackで保留が消えた時だけ `☑️`、本人が止めた時だけ `⏹️` にする。
- 状態遷移では `set_thread_title` を使う。独立したread-heavy subtaskが二つ以上で実時間を短縮する時だけチームを組む。小さい作業、write-heavy作業、単一境界の作業は単独で進める。

## Routing Table

| 条件 | canonical source / skill |
|---|---|
| Project-specific context | 対象repoの `AGENTS.md`。存在しなければ `CLAUDE.md` を互換入力として使う。 |
| 曖昧で大きい設計・実装・デプロイ | `clarify-and-build`。小さく明確な変更には適用しない。 |
| コードの作成・レビュー | `functional-style` と `ponytail`。repo固有規約を優先する。 |
| Nix、Home Manager、ツール導入 | `nix` と対象repoのrunbook。生成済みの `~/.claude` / `~/.codex` は編集しない。 |
| MCP、plugin、agent tool の設計・変更 | `agent-tooling-safety`。 |
| Scrapboxの読書き | `scrapbox-context` と `save-to-scrapbox`。 |
| ブラウザの読取り・視覚確認・対話 | `browser-automation`。 |
| 本人の予定・空き時間 | `apple-calendar`。リマインダーの振り分けは `remind-or-schedule`。 |
| 人へのメール・Beeper・iMessage・DM | 対応する送信skill。本文承認の不変条件は下記に従う。 |
| 人脈活用・紹介依頼・相談メッセージ | `ask-network`。 |
| 返信の収集・統合・元の相手への返信作成 | `collect-and-reply`。 |
| 「さっき／以前／見た／読んだ／やった」など本人の過去活動 | `coast-cli-skill`。候補はliveの正本で照合する。 |

## Shared Agent Skills And Memory

- 共有skillの正本は `prompt/claude-code/skills/<name>/`。Claude/Codexのruntimeコピーを直接編集しない。
- 共有memoryの正本は Claude auto-memory の `MEMORY.md` index とtopic file。非自明な作業ではindexから関連topicだけを読み、driftし得る事実はcanonical fileを再読する。
- memoryの更新は `self-learn` skillだけを使う。`~/.codex/memories` を共有memoryとして読書きしない。

## Shell boundary

- ユーザーがターミナルに貼るコマンドはfish構文、エージェント自身の実行はzsh/POSIX構文を使う。
- GUIを明示されない限り、CLI/APIで同等に実行・検証できる作業はCLI/APIを使う。

@[agent-operations]
