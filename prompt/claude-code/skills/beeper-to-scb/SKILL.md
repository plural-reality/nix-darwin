---
name: beeper-to-scb
description: >
  Beeper（Slack/iMessage/Twitter/Telegram/Matrix 等を集約するローカルメッセージ基盤）の
  グループ会話から「トピック」を漏れなく Scrapbox に反映する skill。日付は軸ではなくメタデータで、
  トピックの網羅性が主目的。各監視グループに 1 枚の「ハブページ」をトピック別に育て(ハブ)、
  重要トピックは関連する既存トピックページにも反映してリンクで繋ぐ(分配)。
  アクセスは Beeper Desktop 内蔵 MCP（mcp__beeper__*）、書込は canonical な scrapbox-write。
  返信/送信も可(確認必須)。
  トリガー:「beeper to scb」「beeper-to-scb」「zos をまとめて」「zos を同期」「Beeper のトピックを Scrapbox に」
  「Beeper のグループまとめて」「○○グループの話を網羅して」「headless beeper」「Beeper で検索/返信」
---

# beeper-to-scb — Beeper 会話のトピックを Scrapbox に網羅する

**原則: 日付ではなくトピックで整理する。** Beeper の会話には「論点・決定・宿題」が流れていく。それを失わずに
Scrapbox 側でトピックとして網羅・更新するのがこの skill のゴール。日付は各トピック内の更新マーカーに過ぎない。

```
Beeper グループ会話 (MCP/API)
  → [あなたがトピックを同定・要約・"情報がどう増えたか"を更新]
  → ハブページ(グループ1枚, トピック別)を verbatim 更新   … 網羅
  → 重要トピックは関連既存ページにも [( 注記＋リンク       … 分配
```

契約は Beeper(MCP) と Scrapbox(scrapbox-write) が持ち、この skill はワークフローのみを持つ。

## 前提
- Beeper Desktop 起動（API `http://127.0.0.1:23373`、token `~/.config/beeper/token`）。MCP `beeper` 登録済(`mcp__beeper__*`)。未ロードのセッションでは後述の raw API フォールバック。
- 書込は `scrapbox-write`（SID は settings.json env）。`[(` 薄表示マークは [[scrapbox-llm-marking]] / [[save-to-scrapbox]] が canonical。

## 設定 / 状態
- 監視グループ: `~/.config/beeper-to-scb/threads.json` の `threads[]` = `{name, chatId, localChatID, project, hubPage}`。zos 登録済。新規グループはここに1行足す（**どのグループがどのハブページか**の single source of truth）。
- 同期ウォーターマーク: `~/.claude/.cache/beeper-to-scb/<localChatID>.json` = `{"lastSortKey","lastSyncedAt"}`。冪等性の鍵（既反映分を二重に出さない）。
- 関連既存ページ(分配先)は**設定に持たず**、会話中のリンクや内容から動的に判断する。

## Beeper MCP ツール
`search_chats`(chatId 解決) / `get_chat` / `list_messages`(`cursor` でページング, `sortKey` が単調増加) / `search_messages` / `send_message`(確認必須)。`text` は Matrix HTML → タグを外す。`isSender:true` は自分の発言。

---

## Workflow 1 (中核): グループ → ハブページのトピック網羅
「zos をまとめて/同期して」で、**前回同期以降の新着**を読み、ハブページのトピックを更新する。

1. `threads.json` から対象グループの `chatId/localChatID/project/hubPage` を得る。ウォーターマーク `lastSortKey` を読む（無ければ「網羅初期化」として遡れる範囲を読む）。
2. `mcp__beeper__list_messages` で `sortKey > lastSortKey` の新着を時系列に収集（`cursor` でページング）。**新着 0 なら書かない**（冪等）。
3. ハブページ `[hubPage]` を読む（`scrapbox-write` で書く前に現状取得）。新着メッセージを**トピックに同定**:
   - 既存トピックの続きなら → そのトピックセクションを**更新**（"情報がどう増えたか"＝問い→回答→現状 を追記。古い結論は消さず、更新履歴が分かる形に）。
   - 新トピックなら → 新しい `[** トピック名]` セクションを作る。
4. 各トピックの構成（**この書式を厳守**）:
   ```
   [(* トピック名]
    [( {主アクション=誰が何をした/何を確認した}]
     [( {結果・サブ要点}]
     [( {その上での結論・次アクション}]
    [( 原文:]
     >> {送信者の発言・全文}[{送信者}.icon]
      >> {それへの返信・全文}[{返信者}.icon]
    [( 関連ページ:]
     [( [関連ページA]]
     [( [関連ページB]]
   ```
   書式ルール（人間が手書きしたものから学習した正＝守る）:
   - **トピック見出し** = `[(* …]`（AI生成なので `[(` 薄表示＋`*`太字。人間が承認すると `[* …]` になる）。
   - **要約は簡潔な要点フロー**。主アクションを書き、その下に結果・結論を**一段ネスト**（"情報がどう増えたか"が見える）。長い散文にしない。詳細は原文に委ねる。各行 `[( …]`。
   - **原文は省略せず全文**。引用は **`>>`** で始め、**末尾に話者アイコン `[名前.icon]`**。**返信は元発言より一段深くインデント**（会話のスレッド構造を残す）。原文 `>>` 行は `[(` を付けない（本人の実発言＝最初から濃い）。
   - **関連ページ** = `[( 関連ページ:]` の下に会話中のリンク先を **1行1リンク `[( [ページ名]]`** で。網羅的に（言及された既存ページは全部）。
   - インデントは半角スペースでネスト（トピック0 → 要約/原文/関連 1 → サブ要点/引用 2 → 返信 3）。
5. ハブページ全体を `scrapbox-write -p <project> -t "<hubPage>" --verbatim`（既存トピック/人間編集を byte 保持しつつ対象トピックだけ差し替え）。`--dry-run` で確認 → 書込。
6. ウォーターマークを最大 sortKey に更新（`mkdir -p ~/.claude/.cache/beeper-to-scb`）。
7. **網羅チェック**: 読み切れていない過去トピックがあれば追って取り込む（このグループのトピックを漏らさない）。URL を報告。

## Workflow 2 (分配): 重要トピックを関連既存ページへ反映
ハブのトピックが既存トピックページ(例 `[シェンドレ下目黒]` `[合同会社 多元現実]`)に関係するとき、そのページにも短い注記とハブへの逆リンクを置く。
1. 関連ページを読む（**既存内容を壊さない**。verbatim or append）。
2. 該当箇所に1行: `[( {要点}（→ [zos] で議論）]`。ハブ↔既存ページの双方向リンクで「トピック網羅」を成立させる。
3. どのページに分配するか曖昧なら聞く。誤爆を避け、確信のある関連ページのみ。

## Workflow 3: オンデマンド要約 / 検索
「最近の○○の話」→ `search_chats`/`search_messages` で該当を読み回答。必要ならハブに反映(Workflow 1)。

## Workflow 4: 返信/送信（確認必須）
`mcp__beeper__send_message`(`chatID`,`text`,任意 `replyToMessageID`)。**宛先(chat title)と本文を提示し明示承認を得てから送信**（durable 許可が無い限り）。

## 定期実行
`~/.claude/scripts/beeper-to-scb-sync.sh`（launchd `com.tkgshn.beeper-to-scb`）が定期的に全監視グループへ Workflow 1(+必要なら 2) を回す。**スケジュールは網羅の更新頻度であって、整理軸は常にトピック**。

## raw API フォールバック（MCP 未ロード/スクリプト時）
```bash
TOKEN=$(cat ~/.config/beeper/token); B=http://127.0.0.1:23373
# chatId は threads.json(source of truth) から引く
CID=$(python3 -c 'import json,urllib.parse,sys; ts=json.load(open(sys.argv[2]))["threads"]; print(urllib.parse.quote(next(x for x in ts if x["name"]==sys.argv[1])["chatId"],safe=""))' zos ~/.config/beeper-to-scb/threads.json)
curl -s -H "Authorization: Bearer $TOKEN" "$B/v1/chats/$CID/messages?limit=80"          # 読取(newest 順, sortKey 付)
# 送信は確認後のみ: curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"text":"…"}' "$B/v1/chats/$CID/messages"
```

## セキュリティ
token は `~/.config/beeper/token` 平文＋MCP ヘッダにも複製。git に乗せない。Beeper は OAuth(`/oauth/*`) 対応なので static token をやめて OAuth 登録に移行も可。API は localhost のみ・remote_access=false。Beeper にアクセスできる＝ブリッジ済み全ネットワークを読めることを前提に扱う。

## 関連
- [[save-to-scrapbox]] / [[scrapbox-llm-marking]] — Scrapbox 書込と `[(` の canonical。
- [[mac-local-data]] — ローカルアプリのデータ取得（Beeper は本 skill が canonical）。
- `~/Developer/beeper-scrapbox-crm` — 同じ API を使う既存 CRM（gateway :8787）。重い同期はこちらに寄せる選択肢。
