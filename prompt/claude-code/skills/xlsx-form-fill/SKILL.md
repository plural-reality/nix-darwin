---
name: xlsx-form-fill
description: >
  既存の Excel フォーム（在留資格変更・入管・行政・申請書など、図形/画像入りの .xlsx）の
  色付き（ハイライト）欄を、ファイルを壊さずに記入し、必要なら返信下書きまで作る skill。
  鉄則は「openpyxl で save しない」＝zip 内の該当セル XML だけ最小改変して図形/画像/共有文字列を温存
  （openpyxl の全面再保存は drawings/media を落とし Apple Numbers が "file format is invalid" で開けなくなる）。
  同梱の xlsx-form.py が highlights 検出と fill を行う。
  トリガー: 「入管」「在留資格」「申請書」「行政フォーム」「Excelフォームに記入」「シートの色付き欄を埋めて」
  「研修の用紙」「xlsx フォーム」「ハイライト部分を記入」「フォームに記入して返信」
---

# xlsx-form-fill — Excel フォーム最小改変記入

## いつ使うか
誰か（財団・自治体・取引先）から **記入用の Excel フォーム**（在留資格変更申請、入管提出書類、
各種申請書など）が送られてきて、**色付き欄を埋めて返す**必要があるとき。

## 鉄則（これを破ると壊れる）
- **openpyxl の `load_workbook`→`save` は禁止**。図形・画像(`xl/drawings`,`xl/media`)・共有文字列・
  印刷設定・サムネイルを落とし、シートに残った図形参照が宙吊りになって **Numbers が開けなくなる**
  （Excel は寛容だが提出先で開けないリスク）。
- 代わりに同梱 `xlsx-form.py fill` を使う。これは **zip 内の該当セル XML だけ**を書き換え、
  他パーツをバイト単位で温存する純粋変換。
- **数値はそのまま数値、ハイフン入り（電話番号・郵便番号）は文字列**で渡す（数値にすると壊れる）。
- 送信系（メール送信・押印）は**勝手にやらない**。下書きまで作ってユーザーに確認。

## ワークフロー

### 0. メール添付の取得
メールが **takagi@plural-reality.com（法人）宛**なら Gmail MCP では読めない（MCP は個人アカウント）。
**gws** で取得する:
```bash
gws gmail users messages list --params '{"userId":"me","q":"件名 has:attachment newer_than:30d"}'
gws gmail users messages get  --params '{"userId":"me","id":"MSGID","format":"full"}'   # attachmentId 取得
gws gmail users messages attachments get --params '{"userId":"me","messageId":"MSGID","id":"ATTID"}'
# → data(base64url) を自分でデコードして保存（作業フォルダは plural-reality Drive のローカル同期先に）
```

### 1. 記入欄の特定
```bash
uv run ~/.claude/skills/xlsx-form-fill/xlsx-form.py highlights form.xlsx
```
塗りつぶし（テーマ色も解決。オレンジ＝accent6 #F79646 等）のセルを、参照・結合範囲・行ラベル付きで列挙。
`tint` 付き（薄い背景）は除外しベタ塗りのみ。これで「どのセルに何を書くか」を読み取る。

### 2. 記入値の取得（受入機関＝多元現実の場合の canonical source）
**live の真実は freee**。署名済み契約書（Drive の業務委託契約書/社員決議書）で代表者の法的表記を確認:
```bash
# 法人番号・所在地・電話・業種(industry_class)
# freee MCP: freee_get_current_company / freee_api_get accounting /api/1/companies/{id}
pdftotext -layout "…/業務委託契約書….pdf" - | grep -E "代表社員|本店|荒川|西日暮里"
```
合同会社多元現実の確定値（**使う前に freee で再確認**。これは便宜上のキャッシュ）:
- 法人番号: `4011503006669`（13桁）
- 所在地: 〒116-0013 東京都荒川区西日暮里2-32-19 203号室
- 電話: 070-1062-6328
- 代表社員（記名押印・指導教員の法的表記）: **高木 俊輔**（"駿介"ではない）
- 主たる業種（業種一覧コード）: `14` 情報通信業（freee industry_class="it"）

### 3. 記入
spec.json（シート名 → {セル参照: 値}）を作って fill:
```bash
uv run ~/.claude/skills/xlsx-form-fill/xlsx-form.py fill form.xlsx spec.json filled.xlsx
```
- 法人番号など1桁ずつのマス目は、各セルに `"T17":4,"U17":0,…` と数値で。
- シート名は highlights の出力どおり（全角スペース注意）。`"xl/worksheets/sheet3.xml"` 直指定も可。

### 4. 検証（必ず）
```bash
unzip -t filled.xlsx >/dev/null && echo ok          # zip 健全
[ "$(unzip -l filled.xlsx|tail -1|awk '{print $2}')" = "$(unzip -l form.xlsx|tail -1|awk '{print $2}')" ] && echo "parts一致"
qlmanage -t -s128 -o /tmp/_ql filled.xlsx 2>&1 | grep -q produced && echo "QuickLook開封OK"
```
元と同じパーツ数＋QuickLook で開ければ正常。読み戻し確認時は `str(v or '')` 禁止（数値0が脱落）。

### 5. 返信下書き（gws・送信しない）
Gmail MCP は個人アカウントなので、法人宛スレッドへの返信は gws で:
```bash
# Python email.message で .eml 生成（From/To/Cc/Subject/In-Reply-To/References＋添付。日本語は lib が MIME 化）
# In-Reply-To/References は元メールの Message-ID（messages get のヘッダから）
cp /tmp/reply.eml ./.reply.eml                       # --upload は cwd 内のみ可
gws gmail users drafts create --params '{"userId":"me"}' \
  --upload .reply.eml --upload-content-type message/rfc822 \
  --json '{"message":{"threadId":"THREADID"}}'       # threadId で元スレッドに連結
rm -f ./.reply.eml
```
→ `labelIds:["DRAFT"]`（未送信）。`messages get` で宛先・添付を検証し、ユーザーが送信。

## 注意
- 「記名押印」欄は氏名のみ記入。社印（印影）が要るかは提出先に確認。
- オレンジ以外で空欄の必須項目（期間等）があれば、勝手に埋めず先方に確認する一文を添える。
- テーマ色の cell index は lt1/dk1 が clrScheme と入れ替わる（8=accent5, 9=accent6）。highlights が解決済み。

## 同梱ツール
`xlsx-form.py`（PEP723 で openpyxl 自動取得）:
- `highlights <in.xlsx>` — 塗りつぶしセル列挙
- `fill <in.xlsx> <spec.json> [out.xlsx]` — 最小改変記入（out 省略/`-` で stdout、in に `-` で stdin）

実績: 2026-06-06 リオ・ネルキ（Leo Nelki, 大和スカラー）在留資格変更（文化活動＝観察研修）申請、
多元現実が受入機関としてシートB/C記入＋林様（大和日英基金）宛下書き作成。
