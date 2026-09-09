# Semantic操作への置換

対象をIDと操作で表せる既存インターフェースを選ぶ。CLI/MCPはtransportであり、冪等性は個々の操作の契約である。`osascript`やPlaywrightをCLIから起動するだけでは、座標・表示状態への依存は減らない。

## 既存経路を探す

| 操作の目的 | 最初に確認する既存経路 | 結果と再実行の確認 |
|---|---|---|
| Driveの資料検索・内容更新 | 法人は`gdrive`の`gws`、個人は接続済みDrive tool。アカウントを先に確定 | fileId、必要なfields、Docsのrevision/差分。createは非冪等。名前だけの重複判定をしない |
| Cosenseの検索・編集 | `scrapbox-context`、`save-to-scrapbox`の`cosense-fetch -r` / `scrapbox-write` | pageId/正確なtitleでraw read→差分→raw read。再実行で同じ行をappendしない |
| メール・Beeperの検索/返信 | 個人`email`、法人`gws gmail`の認可済み読取、Beeper専用skill/tool | thread/message ID、返信先、送信後の正本。timeoutを未送信と決めず照合する。送信承認は対応skillに従う |
| 本人の予定・Reminders | `apple-calendar` / `remind-or-schedule`から、現在公開された署名broker/typed tool | event/reminder ID、calendar/list/marker、対象範囲。appendを冪等としない。TCCを迂回しない |
| Codexのtask表示・状態・整理 | 現在の`list/read/wait/set_thread_title`等のtyped app tool | 返されたtask IDとreadback。タイトルと完了状態は別。UIを開く必要はない |
| GitHubのPR・deploy状態 | `gh`、提供API、repoの既存health/generation endpoint | PR/commit/deployment ID、active generation。レイアウトは別途ブラウザで確認 |
| 公開記事・仕様・PDFの調査 | Web、公式API、PDF抽出 | 出典と必要箇所。画面やページ送りによる転記を減らす |
| UI-onlyな申請・認証・予約 | 公式の公開APIと利用可能な専用toolがなければブラウザ | レビュー画面、必要な本人承認、受付番号/正本。内部APIの推測・Cookie抽出で置換しない |

この表はdiscoveryの入口であり、未実行のコマンドを動作保証しない。サービスごとに現行skillとtool schema/helpを読み、対象host/アカウントの小さなreadで確かめる。金融・申請・送信の履歴レビューでは過去の操作を再実行しない。

## 更新の契約

- 対象IDと現在のrevision/stateを読み、desired stateとの差分だけを作る。同一なら書かず`changed:false`相当を返す。
- サーバーがidempotency keyを保証する作成には、同じ論理操作で同じkeyを使う。payloadが変われば同一keyを再利用しない。保持期限・競合時の扱いも確認する。
- 保証がない作成/送信は、timeout後にID/receiptを照合する。read-before-createだけでは同時実行時の一意性は保証できない。照合不能なら`unknown`として止め、盲目的に再送しない。
- 更新は利用可能ならrevision/ETagの事前条件で競合を拒否する。別の人の変更を読まずに上書きしない。
- 返り値には対象ID、変更有無、正本での状態、未確認を分ける。MCP annotationsはヒントであり実装・実測の代わりにしない。

## 改善候補の判定

`replace`: 同じ目的を既存CLI/API/typed MCPで達成でき、今のreadbackで検証できた。
`hybrid`: データ読取/更新は移せるが、表示・操作感・本人認証は画面に残る。
`keep_ui`: 目的が視覚検証、UI-only、又はユーザーが当該画面操作を明示指定。
`unverified`: 権限、tool coverage、同じ結果になるかが未確認。

証拠は `session ID / call ID又は行 / 操作の目的 / 分類 / 利用可能性の確認日 / readback / 未確認` に絞る。原文、私信、認証値、画面画像を学習用に複製しない。頻度だけで置換を確定せず、操作ごとの判断を`self-learn`へ渡す。

## 一次資料から採用した点（2026-09-09確認）

- [Anthropic: Writing effective tools](https://www.anthropic.com/engineering/writing-tools-for-agents): 高頻度の目的に合う少数のtool、意味のある返り値、実例からのevalとhold-outを採用。既存CLIを包むだけの大量MCPや、全文ログを無制限に渡す方式は採用しない。
- [MCP ToolAnnotations](https://modelcontextprotocol.io/specification/2025-06-18/schema#toolannotations): readOnly/idempotent等はヒント。権限や再試行保証として使わない。
- [AWS: Making retries safe with idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/): callerの論理操作ID、同一keyと異なるpayloadの拒否、timeout後の照合を採用。既存APIにない原子的保証をclient側だけで作れたとは扱わない。
