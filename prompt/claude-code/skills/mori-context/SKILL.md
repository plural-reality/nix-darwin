---
name: mori-context
description: "MoriペンダントのSession・Journal・Transcriptを読み取り専用MCPから取得する。トリガー: 「Moriで調べて」「森の記録」「Moriの日記」「今日の会話」「Moriで何を話した」など、Moriに保存されたライフログの参照。"
---

# Mori Context

Moriの記録が必要なとき、公式Remote MCP `Mori` を使う。

## 境界

- 取得対象は `Session`、`Journal`、`Transcript`。
- MCPは読み取り専用。追加・編集・削除は試みない。
- 公開REST API、API key、PAT、Webhook、公式CLIはまだ提供されていない。ローカルの `mori` はMCPを包む非公式read-only CLI。
- LimitlessのlifelogとMoriの日次Journalは時間的意味が異なる。同じ型・同じ名前へ潰さない。

## 取得手順

1. 期間が明示されていなければ、必要最小限の日付範囲を決める。
2. 一覧には `list_sessions` または `list_journals` を使う。
3. キーワード探索には `search` を使う。
4. 対話的な参照では本文が必要な記録だけ `fetch` する。日次archiveは例外として `mori sync` が未取得Transcript全文を冪等同期する。
5. 回答にはMori由来であること、記録日時、Session / Journal / Transcriptの別を示す。

## 失敗の表現

次を混同しない。

- `取得済み`: MCPから記録を取得できた。
- `記録なし`: 正常に取得できたが対象期間の記録がない。
- `認証が必要`: OAuthの再ログインが必要。
- `一時的に取得できない`: 通信障害またはrate limit。

認証が必要なら、Claude/Codex MCPは各クライアントの `mcp login Mori`、ローカル全文同期は `mori login` を案内する。OAuth access tokenは約1時間、refresh tokenは最終更新から約30日。tokenをprompt、ログ、repo、Nix storeへ出力しない。

## プライバシー

- ライフログは極めて私的な情報として扱う。
- 質問に必要な範囲だけ取得・要約する。
- 第三者へ転送せず、全文を回答へ貼らない。
- 録音参加者名や機微な発言は、依頼に必要な場合だけ表示する。

## 実装上の現状

- Nixの単一のRemote MCP定義をClaude CodeとCodexへ投影する。
- Codex CLI 0.144.6は、利用者所有のClient ID Metadata Documentを明示し、固定loopback callbackを使って公式Remote MCPへ直接接続する。
- 公開client metadataは `https://codex-mori-oauth.tkgshn.com/.well-known/oauth-client-metadata/codex-mori.json`。OAuth tokenはCodexのruntime credential storeだけに保持し、Nixやmetadataへ含めない。
- Claude用client IDの流用、非公式proxy、OAuth token抽出は行わない。
- `mori` CLIは同じ利用者所有client metadataから公式Remote MCPへ直接接続し、自分自身のruntime tokenだけをmode 0600で保持する。
- `mori sync` はJournalを取得せず、Session一覧とTranscript全文だけを `~/.claude/data/pendant-export/mori/YYYY-MM-DD.jsonl` へ保存する。

## 一次情報

- https://wiki.mori.to/app#mcp
- https://help.mori.to/ja/articles/16172150
- https://mcp.mori.to/.well-known/oauth-protected-resource
