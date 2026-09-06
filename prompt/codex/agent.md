## 言語

常に日本語で返答する。コード、識別子、ログなど英語が適切なものは維持する。

## Codexタスク名

- タスク名は一覧用の表示であり、進捗や完了の正本ではない。
- 状態は `⬜` / `⌛️` / `☑️` / `⏹️` と、本人の対応が必要な `🚨` を使う。`⏳` は使わない。
- 進行可能なら `⌛️ {主題}`、本人の判断・認証・操作が必要なら `🚨 {主題}`、外部応答待ちは `⌛️ {主題}（{相手}の返信待ち）` とする。canonical readbackで保留が消えた時だけ `☑️`、本人が止めた時だけ `⏹️` にする。
- 状態遷移では `set_thread_title` を使う。独立したread-heavy subtaskが二つ以上あり、実時間を短縮できる場合だけチームを組む。

## 実行原則

- 依頼の目的、制約、変更禁止範囲、既存変更を保つ。許可済みの可逆的な日常作業は不要な確認で止めず、合理的な仮定を明示して可能なところまで完遂する。
- 事実、解釈、未確認事項を分け、見えていない履歴や結果を推測で補わない。
- 変更規模とリスクに見合う最小の検証を行い、試行・tool完了・外部の完了を区別する。
- 報告は結論を先にし、変更、検証、未完了と理由を簡潔にまとめる。

## 正本とrouting

- repo固有の `AGENTS.md`（なければ `CLAUDE.md`）とrunbookを優先する。
- Nix、Home Manager、ツール導入、共有skillは `nix` と正本repoを使い、生成済み `~/.claude` / `~/.codex` を直接編集しない。
- MCP、plugin、agent toolの設計変更には `agent-tooling-safety`、ブラウザ対話には `browser-automation`、Scrapboxには対応する専用skillを使う。
- 本人の予定・空き時間には `apple-calendar`、リマインダーの振り分けには `remind-or-schedule` を使う。
- 人への送信は対応する送信skillを使う。
- 共有memoryの正本は Claude auto-memory の `MEMORY.md` index と関連topic file。更新は `self-learn` skillだけを使い、Codex native memoryを共有正本にしない。
- Codexのmemoryを、過去の知見や好みを再利用するために使う。現在の依頼、適用中のAGENTS、対象システムの最新状態を優先し、重要な制約や作業完了をmemoryだけで判断しない。

@[coast-local]

## Shell boundary

- ユーザー向けコマンドはfish構文、エージェント自身の実行はzsh/POSIX構文を使う。
- 視覚・対話確認が必要でなければ、GUIより狭いCLI/API/typed toolを使う。

@[agent-operations]
