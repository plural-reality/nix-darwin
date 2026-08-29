---
name: mori-context
description: "MoriペンダントのSession・Journal・Transcriptを読み取り専用MCPから取得する。トリガー: 「Moriで調べて」「森の記録」「Moriの日記」「今日の会話」「Moriで何を話した」など、Moriに保存されたライフログの参照。"
---

# Mori Context

Moriの記録が必要なとき、公式Remote MCP `Mori` を一次のlive取得元として使う。過去の
Session / Transcript を確かめるときは、同じRemote MCPを読む読み取り専用CLI `mori` も使う。
`mori` は、Remote MCPに見えない過去Sessionだけをローカルの全文archiveから補う。

## 境界

- 取得対象は `Session`、`Journal`、`Transcript`。
- MCPは読み取り専用。追加・編集・削除は試みない。
- 公開REST API、API key、PAT、Webhook、公式CLIはまだ提供されていない。ローカルの `mori` はMCPを包む非公式read-only CLI。
- LimitlessのlifelogとMoriの日次Journalは時間的意味が異なる。同じ型・同じ名前へ潰さない。
- MoriのJournalはMoriが生成する日次の要約であり、Session / Transcriptのarchiveとは別物である。`mori sync` と過去記録のfallbackはJournalを正本にも取得対象にもせず、全文Transcriptだけを扱う。

## 取得手順

1. 期間が明示されていなければ、必要最小限の日付範囲を決める。
2. 一覧には `list_sessions` または `list_journals` を使う。
3. キーワード探索には `search` を使う。
4. 対話的な参照では本文が必要な記録だけ `fetch` する。日次archiveは例外として `mori sync` が未取得Transcript全文を冪等同期する。
5. 回答にはMori由来であること、記録日時、Session / Journal / Transcriptの別を示す。

### 過去のSessionを参照する場合

Remote MCPの `list_sessions` が空でも、過去に記録が存在しなかったとは断定しない。Remote MCPの
保持・可視性が浅く、既に同期済みの全文がローカルarchiveにだけ残っていることがある。

期間を絞って次を使う。`mori` はRemote MCPを先に読み、そこで欠けたSession / Transcriptだけを
`~/.claude/data/pendant-export/mori/YYYY-MM-DD.jsonl` の読み取り専用archiveから補う。archiveへの
書込みは `mori sync` だけが行う。

```bash
mori sessions --from YYYY-MM-DD --to YYYY-MM-DD
mori date YYYY-MM-DD
mori transcript <session-id>
```

- archiveで見つかった記録も出典はMoriだが、「Moriの同期済みTranscript archive」と明記する。
- Remote MCPにもarchiveにもないことは「この経路では記録を確認できなかった」と表現し、会話が無かった証拠にはしない。
- 一覧を見てから原文が必要なSessionだけ `mori transcript` で開く。全文を不必要に回答へ貼らない。

## 失敗の表現

次を混同しない。

- `取得済み`: MCPから記録を取得できた。
- `archiveから取得済み`: Moriの同期済み全文archiveから過去のSession / Transcriptを取得できた。
- `記録なし`: Remote MCPとarchiveの両方で対象期間の記録を確認できなかった。
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
- `mori sync` はJournalを取得せず、Session一覧とTranscript全文だけを `~/.claude/data/pendant-export/mori/YYYY-MM-DD.jsonl` へ保存する。`mori sessions` / `date` / `transcript` はRemote MCPを優先し、Remote MCPにない同期済みSessionをこのarchiveから補う。

## 一次情報

- https://wiki.mori.to/app#mcp
- https://help.mori.to/ja/articles/16172150
- https://mcp.mori.to/.well-known/oauth-protected-resource
