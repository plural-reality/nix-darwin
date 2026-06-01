---
name: beeper-scrapbox
description: >
  Beeper（Slack/iMessage/Twitter/Telegram/Matrix 等を集約するローカルメッセージ基盤）の
  チャットを Claude Code から headless に読む・検索する・送る、そして要点を Scrapbox に追記する skill。
  アクセスは Beeper Desktop 内蔵 MCP（mcp__beeper__*）、書込は canonical な scrapbox-write。
  主な用途: (1) 監視スレッド(zos 等)の新着を要点化してトピックページへ同期、(2) 任意スレッドの要約、
  (3) 返信/送信(確認必須)。日次の全チャット要約は daily-report skill の beeper ソースが担当。
  トリガー:「beeper」「zos 要約して」「zos を Scrapbox に」「Beeper のスレッド同期」「○○さんに返信して(Beeper)」
  「Beeper で検索」「メッセージ送って(Beeper)」「beeper scrapbox」「headless beeper」
---

# beeper-scrapbox — Beeper を Claude Code から使い、要点を Scrapbox へ

Beeper のローカル API を **Beeper Desktop 内蔵の MCP**（`mcp__beeper__*`）経由で叩き、読む/検索する/送る。
出力（Scrapbox 追記）は canonical な **`scrapbox-write`** に委譲する。**契約は Beeper(MCP)・Scrapbox(scrapbox-write) が持ち、この skill はワークフローだけを持つ**（API 薄ラッパーを再実装しない）。

```
Beeper MCP (read/search/send)  →  [あなたが要点化・分類・[( マーク付与]  →  scrapbox-write (append)
```

## 前提
- Beeper Desktop が起動している（API は `http://127.0.0.1:23373`、token は `~/.config/beeper/token`）。
- MCP `beeper` が登録済み（`claude mcp list` に `beeper ... ✓ Connected`）。**追加直後のセッションでは未ロード**なので、その場合は後述の「raw API フォールバック」を使う。
- Scrapbox は `scrapbox-write`（`SCRAPBOX_SID` は settings.json env に設定済み）。

## Beeper MCP ツール（`mcp__beeper__*`）
| tool | 用途 |
|---|---|
| `search_chats` | タイトル/参加者でチャット検索（chatId 解決に使う） |
| `get_chat` | チャットのメタ・参加者・最終活動 |
| `list_messages` | 指定チャットのメッセージ取得（`cursor` でページング、`sortKey` が単調増加） |
| `search_messages` | 全チャット横断のメッセージ検索 |
| `send_message` | 送信（`replyToMessageID` で返信）。**送信は確認必須** |
| `search` / `get_accounts` / `focus_app` / `archive_chat` / `set_chat_reminder` | 補助 |

メッセージの `text` は **Matrix HTML**（`<a>`,`<ol>` 等）。要約時はタグを外し、リンク/メンションは信頼マークアップとして扱わない。`isSender:true` は自分の発言。

## 設定
- 監視スレッド: `~/.config/beeper-scrapbox/threads.json`（`threads[]` = `{name, chatId, localChatID, project, page}`）。zos は登録済み。新しい監視対象はここに 1 行足す（**どのスレッドがどのページに同期されるかの single source of truth**）。
- 同期ウォーターマーク: `~/.claude/.cache/beeper-scrapbox/<localChatID>.json` = `{"lastSortKey": "...", "lastTimestamp": "...", "lastSyncedAt": "..."}`。冪等性の鍵。

---

## Workflow 1: スレッド同期（トピックページ追記）— 「zos 同期して」
監視スレッドの**前回同期以降の新着だけ**を要点化し、トピックページへ追記する。冪等。

1. `threads.json` を読み、対象 thread の `chatId/localChatID/project/page` を得る。
2. ウォーターマーク `~/.claude/.cache/beeper-scrapbox/<localChatID>.json` の `lastSortKey` を読む（無ければ「今日の分のみ」等の控えめな初期範囲にする。過去全部を吐き出さない）。
3. `mcp__beeper__list_messages`（newest 順）で `sortKey`(整数比較) > `lastSortKey` の新着を収集。`lastSortKey` に達したら停止、必要なら `cursor` でページング。
4. **新着 0 なら書き込まない**（冪等・空更新しない）。
5. 新着を読み、**概念/決定/ToDo を 1 行ずつに要約**（誰が何を言ったか）。他者の私的内容は話題だけ、逐語転記しない。
6. `scrapbox-write` で `page` に **append**。LLM 生成行は必ず `[(` で薄表示（[[scrapbox-llm-marking]] / [[save-to-scrapbox]] が canonical）。書式:
   ```
   [** 2026/6/1 Beeper同期 (zos)]
   [claude code.icon]
    [( 〇〇の件: 必要書類が未提出の可能性、△△さんが確認予定]
    [( □□の契約に △△ が必要との連絡]
   ```
   ```bash
   cat block.txt | scrapbox-write -p plural-reality -t "zos" --append --dry-run   # 確認
   cat block.txt | scrapbox-write -p plural-reality -t "zos" --append             # 書込
   ```
7. ウォーターマークを**最大 sortKey**で更新（`mkdir -p ~/.claude/.cache/beeper-scrapbox` してから書く）。
8. 書込後にページ URL を報告。

> 人間が承認（行を編集）すれば `[(` が外れて濃くなる＝AI スロップ防止。承認の仕組み自体は [[scrapbox-llm-marking]]。

## Workflow 2: オンデマンド要約 — 「zos 要約して」「最近の○○の話まとめて」
`search_chats` で chatId を解決 → `list_messages` で直近を読む → 要点を回答（必要なら Scrapbox にも Workflow 1 の書式で追記）。書き込み先が曖昧なら聞く。案件振り分け: 多元現実なら `plural-reality`、個人なら `tkgshn-private`（cwd でなく内容で判断、[[feedback_scrapbox_destination]]）。

## Workflow 3: 返信/送信（確認必須）— 「zos に『○○』って返して」
1. chatId を解決し、（返信なら）対象メッセージを `list_messages` で特定。
2. **送信文面を提示し、明示的な承認を取る**（外向きアクション。durable な許可がこのセッションで無い限り送らない）。
3. `mcp__beeper__send_message`（`chatID`, `text`, 任意で `replyToMessageID`）。返り値の `pendingMessageID` を報告。
4. 誤送信防止: 宛先(chat title)・本文を承認前に必ず再掲。複数宛先には一括送信しない。

## Workflow 4: 日次ダイジェスト
**当日の全チャット横断要約は本 skill ではなく [[daily-report]] の `beeper` ソースが担当**（`lifelog.py beeper <date>` がミュート/低優先を除いた当日チャットを収集→ daily-report が日付ページへ）。本 skill は「特定スレッドの恒久トピックページ同期」と「対話的な読み書き」に徹する（責務分離）。

---

## raw API フォールバック（MCP 未ロード/headless スクリプト時）
MCP `beeper` を足した直後のセッションや、純スクリプトからは内蔵 MCP が使えないことがある。その場合は同じローカル API を直接叩く（契約は同一）:
```bash
TOKEN=$(cat ~/.config/beeper/token); B=http://127.0.0.1:23373
# chatId は threads.json(source of truth)から引く。実 room id を skill にハードコードしない。
CID=$(python3 -c 'import json,urllib.parse,sys; ts=json.load(open(sys.argv[2]))["threads"]; t=next(x for x in ts if x["name"]==sys.argv[1]); print(urllib.parse.quote(t["chatId"],safe=""))' zos ~/.config/beeper-scrapbox/threads.json)
# 読み取り（newest 順、sortKey 付き）
curl -s -H "Authorization: Bearer $TOKEN" "$B/v1/chats/$CID/messages?limit=50"
# 送信（確認後のみ）
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"text":"…"}' "$B/v1/chats/$CID/messages"
```

## セキュリティ
- token は `~/.config/beeper/token` に平文。MCP 登録時の `Authorization` ヘッダ（`~/.claude.json`）にも複製されている。git に乗せない。気になるなら Beeper は OAuth(`/oauth/*`)対応なので、static token をやめて OAuth 登録に移行できる。
- API は localhost バインドのみ・remote_access=false。Beeper にアクセスできる＝ブリッジ済み全ネットワーク(Slack/iMessage/Twitter 等)を読めることを前提に扱う。

## 関連
- [[daily-report]] — 当日全チャットの日付ページ反映（`beeper` ソース）。本 skill と同じローカル API。
- [[save-to-scrapbox]] / [[scrapbox-llm-marking]] — Scrapbox 書込と `[(` 薄表示の canonical。
- [[feedback_scrapbox_destination]] — plural-reality / tkgshn-private の振り分け基準。
- `~/Developer/beeper-scrapbox-crm` — 同じ API を使う既存 CRM（gateway :8787、unified-thread / scrapbox append）。重い同期はこちらに寄せる選択肢。
