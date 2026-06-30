---
name: beeper-to-scb
description: >
  Beeper（Slack/iMessage/Twitter/Telegram/Matrix 等を集約するローカルメッセージ基盤）の
  グループ会話を要約し、Scrapbox の「日付ページ（日報）」に『Beeperグループからのまとめ』として書く skill。
  整理はトピック単位（時系列の羅列でなく、論点ごとに "情報がどう増えたか" を畳み込む）。
  関連する既存トピックページへはリンクで繋ぐ（分配）。
  アクセスは Beeper Desktop 内蔵 MCP（mcp__beeper__*）、書込は canonical な scrapbox-write。返信/送信も可(確認必須)。
  トリガー:「beeper to scb」「beeper-to-scb」「zos をまとめて」「zos を日報に」「Beeper のグループまとめて」
  「○○グループの話をまとめて」「headless beeper」「Beeper で検索/返信」
---

# beeper-to-scb — Beeper グループ会話を日付ページにまとめる

**出力先は日付ページ（日報, `YYYY/M/D`）**。その日のグループ会話を `[** Beeperグループ（[グループ名]）からのまとめ]`
セクションとして書く。**整理軸はトピック**（時系列の羅列でなく論点ごと、"情報がどう増えたか"を残す）。
関連する既存トピックページへは**リンク**で繋ぐ（＝分配）。

```
Beeper グループ会話 (MCP/API)
  → [トピックを同定・簡潔に要約・原文を保持]
  → 日付ページの [** Beeperグループ（[名]）からのまとめ] に topic ブロックを verbatim 追記
  → 各 topic の「関連ページ」に既存ページへのリンク（分配）
```

契約は Beeper(MCP) と Scrapbox(scrapbox-write) が持ち、この skill はワークフローのみ。

## 前提
- Beeper Desktop 起動（API `http://127.0.0.1:23373`、token `~/.config/beeper/token`）。MCP `beeper` 登録済(`mcp__beeper__*`)。未ロードのセッションは後述 raw API フォールバック。
- 書込は `scrapbox-write`（SID は settings.json env）。`[(` 薄表示マークは [[scrapbox-llm-marking]] / [[save-to-scrapbox]] が canonical。

## 設定 / 状態
- 監視グループ: `~/.config/beeper-to-scb/threads.json` の `threads[]` = `{name, chatId, localChatID, project}`。zos 登録済。`project` で書込先プロジェクト（多元現実=plural-reality）を決め、日付ページは会話日から決まる。
- ウォーターマーク: `~/.claude/.cache/beeper-to-scb/<localChatID>.json` = `{"lastSortKey","lastSyncedAt"}`。冪等性の鍵。

## Beeper MCP ツール
`search_chats`(chatId 解決) / `get_chat` / `list_messages`(`cursor` ページング, `sortKey` 単調増加) / `search_messages` / `send_message`(確認必須)。`text` は Matrix HTML → タグを外す。`isSender:true` は自分の発言。

---

## Workflow 1 (中核): グループ → 日付ページの『Beeperグループからのまとめ』
1. `threads.json` から対象グループの `chatId/localChatID/project` を得る。ウォーターマーク `lastSortKey` を読む。
2. `mcp__beeper__list_messages` で `sortKey > lastSortKey` の新着を時系列収集。**新着 0 なら書かない**（冪等）。
3. 会話を**トピック単位に束ねる**。1つのやり取り（問い→回答→…）は1トピックにまとめ、日付境界を跨いでも会話として繋がっていれば同じまとめに入れて良い（その旨を時刻で明示）。
4. 書込先 = `project` の **日付ページ `YYYY/M/D`**（会話の起点日）。そのページの `[** Beeperグループ（[グループ名]）からのまとめ]` セクションに、各トピックを下記書式で追記/更新。ページの他セクション（[** やったこと] 等）は **verbatim で byte 保持**。`--dry-run` 確認 → 書込。
5. ウォーターマークを最大 sortKey に更新（`mkdir -p ~/.claude/.cache/beeper-to-scb`）。URL を報告。

### 書式（厳守・手書き 5/31 に準拠）
**インデント鉄則: ネストは「1段ずつ」。1段＝半角スペース1個。親より必ず "ちょうど1段だけ" 深くする。一度に2段以上飛ばすのは厳禁**（例: 2スペース→6スペースのようなジャンプは禁止。必ず 2→3→4 と刻む）。
```
[** Beeperグループ（[グループ名]）からのまとめ]
 [(* トピック名]
  [( {主アクション=誰が何をした/何を確認した}]
   [( {結果}]
   [( → {結論・次アクション}]
  [( 原文:]
   >> {送信者の発言・全文}[{送信者}.icon]
    >> {それへの返信・全文}[{返信者}.icon]
  [( 関連ページ:]
   [( [ページA]]
   [( [ページB]]
```
- インデント段数（半角スペース数）: `[** …]`=0 / `[(* トピック]`=1 / 主アクション・`[( 原文:]`・`[( 関連ページ:]`=2 / 結果や結論・`>>` 引用・関連リンク=3 / 引用への返信=4。**各行は親よりちょうど +1 段**。
- **トピック見出し** `[(* …]`（AI生成＝`[(` 薄表示＋`*`太字。人間が承認すると `[* …]`）。**セクション**はグループ名をリンク。
- **要約は簡潔な要点フロー**。主アクション(2段)の下に、その結果・結論を1段下(3段)に置く（"情報がどう増えたか"を段で示す。長い散文にしない、詳細は原文へ）。
- **原文は省略せず全文**。各発言を `>>` で始め**末尾に話者アイコン `[名前.icon]`**。**返信は元発言の1段下**(引用3段→返信4段)でスレッドを示す。`>>` 行は `[(` を付けない（本人の実発言＝最初から濃い）。
- **関連ページ** = `[( 関連ページ:]`(2段) の下に、言及された既存ページを `[( [ページ名]]`(3段) で1行1リンク網羅（＝分配）。

## Workflow 2: オンデマンド要約 / 検索
「最近の○○の話」→ `search_chats`/`search_messages` で読み回答。必要なら Workflow 1 で日付ページに反映。

## Workflow 3: 返信/送信（確認必須）
`mcp__beeper__send_message`(`chatID`,`text`,任意 `replyToMessageID`)。**宛先(chat title)と本文を提示し明示承認を得てから送信**（durable 許可が無い限り）。

## 定期実行
`~/.claude/scripts/beeper-to-scb-sync.sh`（launchd `com.tkgshn.beeper-to-scb`）が定期的に各監視グループへ Workflow 1 を回し、該当日付ページの『Beeperグループからのまとめ』を更新する。

> daily-report との共存: daily-page.py は自分の管理セクション(Schedule/やったこと/メモ)だけ再生成し、この『Beeperグループからのまとめ』セクションは触らない。同日に両方走る場合は daily-report の後にこの skill を走らせる（過去日は再生成されないので問題ない）。

## raw API フォールバック（MCP 未ロード/スクリプト時）
```bash
TOKEN=$(cat ~/.config/beeper/token); B=http://127.0.0.1:23373
CID=$(python3 -c 'import json,urllib.parse,sys; ts=json.load(open(sys.argv[2]))["threads"]; print(urllib.parse.quote(next(x for x in ts if x["name"]==sys.argv[1])["chatId"],safe=""))' zos ~/.config/beeper-to-scb/threads.json)
curl -s -H "Authorization: Bearer $TOKEN" "$B/v1/chats/$CID/messages?limit=80"          # 読取(newest 順, sortKey 付)
# 送信は確認後のみ: curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"text":"…"}' "$B/v1/chats/$CID/messages"
```

## セキュリティ
token は `~/.config/beeper/token` 平文＋MCP ヘッダにも複製。git に乗せない。Beeper は OAuth(`/oauth/*`) 対応。API は localhost のみ・remote_access=false。Beeper にアクセスできる＝ブリッジ済み全ネットワークを読める前提で扱う。

## 関連
- [[daily-report]] — 同じ日付ページの管理セクションを書く skill（住み分け: 上記の共存ノート）。
- [[save-to-scrapbox]] / [[scrapbox-llm-marking]] — Scrapbox 書込と `[(` の canonical。
- [[mac-local-data]] — ローカルアプリのデータ取得（Beeper は本 skill が canonical）。
- `~/Developer/beeper-scrapbox-crm` — 同じ API を使う既存 CRM（gateway :8787）。
