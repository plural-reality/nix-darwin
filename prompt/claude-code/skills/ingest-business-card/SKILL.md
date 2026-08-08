---
name: ingest-business-card
description: 名刺画像をOCRし、直近のApple Calendar・Scrapbox・メッセージ・Limitless/Plaud等を照合して、取得イベント、会話、表記揺れ、公開プロフィールを根拠付きで統合したScrapbox人物ページを作る。名刺写真から人物CRMを起こす、名刺交換した場を推定する、既存人物ページとの重複を解消する、Gyazo画像付きScrapboxページを作成する、写真ライブラリから抽出済みの名刺候補を処理する依頼で使う。
---

# 名刺取り込み

名刺を正本とする連絡先情報と、時系列ログを正本とする接点情報を、一つの人物ページへ統合する。画像処理・OCR・収集・照合・生成を先に完了し、Gyazo/Scrapboxへの副作用を最後のcommit phaseへ隔離する。

詳細なsource outcome、照合結果、previewの型は `references/output-contract.md` を読む。

## 不変条件

- 名刺、会話ログ、公開情報を混同せず、主張の近くに根拠を残す。
- 写真の撮影日時だけで取得日時を断定しない。
- 名刺cropは原画素の決定的変換に限定し、生成AIで文字やロゴを再生成しない。
- Apple Calendarは本人のチェック付きcalendarだけを読む。
- Coastは候補探索だけに使い、元ログや現在状態の正本にしない。
- 同名人物を自動統合しない。氏名、所属、役職、連絡先、会話文脈の複数一致を要求する。
- 外部連絡、ページ削除、既存ページの自動改名をしない。
- Gyazoを外部公開面として扱う。送信画像とScrapbox差分を実call直前にpreviewする。

## Workflow

### 1. 入力と境界を固定する

名刺画像または写真ライブラリから明示的に選択されたasset、lookback（既定21日）、Scrapbox project、画像公開モードを入力とする。次を最初に固定する。

- objective: 人物ページと取得イベントを根拠付きで作る
- non-goals: 外部連絡、根拠のない人物統合、未previewの外部upload/write
- canonical sources: 名刺原本、Apple Calendar、Scrapbox、Limitless/Plaud、メッセージ、公式Web
- write boundary: local preview、またはpreview承認後のGyazo/Scrapbox commit
- completion proof: 画像hash、source outcomes、Gyazo URL、Scrapbox API readback

写真ライブラリの定期scanでは、全画像をexportしない。read-only brokerが返す安定asset IDのsnapshot差分を取り、新規IDから名刺候補として選ばれた画像だけを一時領域へexportする。scan state、候補判定、外部commitを別の状態として報告する。

### 2. 原画像からevidence bundleを作る

原本SHA-256を記録し、向き補正、四隅検出、perspective crop、長辺1600px程度への縮小を行う。派生画像SHA-256も記録する。OCR結果は値、候補表記、confidence、画像上の領域を持つ構造として保持する。

氏名、読み、Latin表記、所属、部署、役職、メール、電話、住所、Web、SNS、同僚・ブランド・事業名を抽出する。連絡先の生値はcommit対象が確定するまで不要なログへ再掲しない。

### 3. 既存人物と表記揺れを探索する

`scrapbox-context` に従い、`plural-reality`、`takalog`、`tkgshn-private` を横断する。完全一致、空白除去、姓名順、かな、Latin表記、所属併記を検索し、`exact_page | alias_page | bracket_mention | plain_text_mention | no_record` を分ける。

対象projectと同種の名刺由来人物ページを2〜4件読み、そのformatを正本にする。人物ページ、イベントページ、会話ページは同じ本文を複製せず相互linkする。

### 4. 取得イベントを推定する

lookback内のApple Calendar、Scrapbox、Limitless/Plaud、メッセージを収集し、各sourceを `collected | no_record | temporarily_unavailable | auth_required | unsupported` で記録する。

会話内の名乗り・所属・役職、会話時刻とイベント時間帯、イベントページの人物言及、メッセージ参加者、写真撮影時刻の順で評価し、`high | medium | low | unresolved` と採否理由を残す。STT誤認識は訂正済みの事実へ変えず、照合候補のまま扱う。

### 5. 会話と切り出しページを接続する

Limitless/Plaudから、相手の発言、ユーザーの発言、同席者の発言を区別して次を抽出する。

- 話した主題
- 相手の関心、課題、判断軸
- ユーザーが提示した仮説
- 合意した次の行動と、まだ合意していない提案
- 関連人物、組織、project

話者labelが実名でなければ帰属確度を明記し、`Unknown`話者を人物固有の見解へまとめない。

同日会話が独立ページに切り出されている場合は、API readbackしたexact canonical titleを日付付き会話sectionの直下へlinkする。会話ページ側にも人物と取得イベントへのbacklinkを置く。別taskが会話ページを作成中なら、推測titleのghost linkを先に作らず、所有taskと調整してcanonical title確定後に人物ページをCAS更新する。

### 6. 公開情報を検証する

Web検索では本人、所属組織、行政、大学、公的機関など一次情報を優先する。現在の役職、経歴、論文、projectを別々に確認し、事実と推論を分ける。氏名だけでなく所属、専門、時系列を照合して別人混同を避ける。

### 7. Scrapbox本文を作る

`save-to-scrapbox` のlocal style contractを優先し、独自property schemaを持ち込まない。`image::`、`email::`、`role::`、`source::`、`provenance::`等の `key:: value` を使わない。

人物ページは原則次の順にする。

- 冒頭: 読み/Latin表記、所属、役職、接点
- Gyazo URL: bare linkの独立行
- `[** 名刺（一次情報）]`: `氏名:`、`別表記:`、`所属:`、`肩書:`等の通常label
- `[** 公開情報]`: 主張の近くに一次URL
- `[** YYYY/M/D の会話（媒体）]`: 独立会話ページlink、取得event、時刻、論点、合意/未合意
- `[** 未確認・要注意]`: STT、話者label、別人混同、未検証claim
- `[** 関連]`: 会社、同僚、event、概念、project

AI生成行を `[( ...]` で包み、人間の既存行は包み直さない。複数行の最初の実質的なAI行だけに実行agentのiconを付ける。genericな`会話`/`sources` headingや末尾property形式provenanceを作らない。

### 8. Preview gate

外部call直前に一つのimmutable preview bundleを提示する。

- crop画像とhash
- unredacted / contact-redacted
- Gyazoへ送る正確な画像
- Scrapbox project、exact title、全文diff
- 新規作成か既存更新か
- unresolved identity/event候補

対話runでは対象ごとの明示承認後にcommitする。無人定期runは、automation promptに対象project、画像公開mode、Gyazo upload、Scrapbox writeへのstanding authorizationが明記されている場合だけ、同じpreviewをaudit recordとして保存して自動commitできる。承認内容が欠けるrunではpreviewをreview queueへ残す。

### 9. Commitとreadback

承認済みcropをGyazoへuploadし、返ったURLをimmutable inputとして本文を確定する。`save-to-scrapbox` に従いdry-run、write、API readbackを行う。正確なproject/title、Gyazo URL、人物・会社・event・会話ページlink、LLM mark、source URLをreadbackして初めてverifiedとする。

失敗時は再実行可能なpreview bundleを残し、`detected`、`prepared`、`uploaded`、`written`、`verified`を区別する。
