---
name: meguro-pool-update
description: 目黒区民センター体育館プールの個人利用スケジュールを目黒区公式PDFから取得し、iCloudカレンダー「目黒区民プール」を当月洗い替えする。「往復コース(ラップ用)が使える時間だけ」を載せる。トリガー: 「プール更新」「目黒区民プール更新」「meguro-pool-update」、月次launchd。
---

# meguro-pool-update — 月次プールスケジュール洗い替え

目黒区民センター体育館プール(下目黒3丁目の最寄り)の「個人利用」枠を公式PDFから取得し、iCloudカレンダー **「目黒区民プール」** を当月洗い替えする。掲載方針は「**往復コース(ラップ用=3・4コース)が使える時間だけ**」(ユーザーはトライアスロン練習で連続周回したい)。

このスキルは「プールPDF→ルール解釈→汎用イベントJSON」までを担当し、**カレンダー書込みは汎用窓口 [apple-calendar] に委譲**する(iCloud固定・位置情報・洗い替えはそちらの責務)。

パイプライン: `curl PDF → pdftotext → 解釈(このskill) → 汎用JSON → ~/.claude/scripts/calendar/apply.swift`。解釈以外は決定的。

## 定数
- カレンダー名: `目黒区民プール`（iCloud。屋内/屋外はイベント名接頭辞 `[屋内]`/`[屋外]` で区別）
- 書込み: 汎用アプライヤ `~/.claude/scripts/calendar/apply.swift`（apple-calendar スキルのIO境界）
- 中間JSON: `~/.claude/scripts/meguro-pool/<YYYY-MM>.json`（出力例: `2026-06.json`）
- 位置(defaultLocation・確定値): `{ "title": "目黒区民センター体育館プール", "address": "東京都目黒区目黒2-4-36", "lat": 35.635733, "lon": 139.708242 }`
- 当月: `date +%Y` と `date +%m`

## 手順

### 1. 当月PDFのURLを解決
- index を取得: `curl -sL https://www.city.meguro.tokyo.jp/sports/bunkasports/sports/indoorpool_nittei.html` し、`center-jpn` を含む `.pdf` リンクを抽出（`grep -oE 'https://[^"]*center-jpn[^"]*\.pdf'` 等）。当月(YYYYMM)のものを選ぶ。
- 取れなければ fallback: `https://www.city.meguro.tokyo.jp/documents/4896/<YYYYMM>-center-jpn.pdf`（documentID 4896 は変わりうるので index 抽出を優先）。

### 2. PDF → テキスト
```
curl -sL <pdf_url> -o /tmp/meguro-center.pdf
pdftotext -layout /tmp/meguro-center.pdf /tmp/meguro-center.txt
```
`/tmp/meguro-center.txt` を Read する。

### 3. 解釈 → 汎用イベントJSON（最重要・判断ルール）
各日について「往復コースが使える連続時間ブロック」を出す。コース運用は フリー(1・2) / 往復(3・4) / 週間プログラム占用(5・6)。

**カレンダーから除外する時間**:
1. **全面休止** = 大会 / 全面貸切 / こども水泳教室 / 赤十字講習など「一般公開なし・全面公開休止」の時間。
2. **往復コースなし** = 土曜「子どもサポートプラン」9:00–18:00（フリーのみ）→ 土曜は **18:00–22:00だけ**。PDFに「往復コースなし/フリーのみ」と明記された時間も同様に除外。

**載せる時間**:
- 平日レッスン（5・6コース占用）は **往復(3・4)が生きる** ので含め、`notes` に「HH:MM–HH:MM ◯◯(5・6コース)」と注記。
- 半面貸切/半面のみ公開は、明示の「往復なし」記載がなければ残し `notes` に注記。

**分割**: 全面休止で日が割れる場合は複数イベントに分ける（例 9:00–15:40 と 20:50–22:00）。
**title**: `[屋内] 個人利用 H:MM–H:MM`。**notes**: その日の制限・レッスン・割引(全面貸切後の再開枠は大人300円)等。

### 4. 夏季（7〜9月）は屋外も追加
- `curl -sL https://www.city.meguro.tokyo.jp/sports/bunkasports/sports/center_okugai_pool_ippankokai.html`（または WebFetch）で屋外プールの開設期間・時間・大会日を確認。
- 開設期間（近年 7/1–9/10、10:00–20:00）の各日に `[屋外] 個人利用 H:MM–H:MM`（50m長水路）を追加。大会で50mが使えない時間は除外、`notes` に注記。屋外は同住所なので defaultLocation が効く。

### 5. 適用（洗い替え）= apple-calendar に委譲
- `~/.claude/scripts/meguro-pool/<YYYY-MM>.json` に Write（schema 下記、`mode: "replace-month"`）。
- `swift ~/.claude/scripts/calendar/apply.swift ~/.claude/scripts/meguro-pool/<YYYY-MM>.json` を実行。
- 出力 `applied N / removed M / mode=replace-month / source=iCloud` を確認（source が iCloud であること）。

### 6. 失敗時
- 当月PDFが未掲載なら翌月分でリトライ、それも無ければ何もせず終了（既存カレンダーは保持＝洗い替えしない）。

## 汎用イベントJSON schema（apple-calendar 準拠）
```json
{
  "calendar": "目黒区民プール",
  "mode": "replace-month",
  "year": 2026, "month": 6,
  "defaultLocation": { "title": "目黒区民センター体育館プール", "address": "東京都目黒区目黒2-4-36", "lat": 35.635733, "lon": 139.708242 },
  "events": [
    { "title": "[屋内] 個人利用 18:00–22:00", "start": "2026-06-06T18:00", "end": "2026-06-06T22:00", "notes": "..." }
  ]
}
```
（`start`/`end` は `yyyy-MM-ddTHH:mm`。location は defaultLocation が全イベントに効く。詳細は apple-calendar スキル。実例: `~/.claude/scripts/meguro-pool/2026-06.json`）

## 下流2: intervals.icu トレーニングカレンダーへの重ね込み（2026-06-06 追加）

プール開放枠は Apple カレンダーだけでなく **intervals.icu** にも NOTE として重ねる（FORMスイム計画と同じ盤面で「泳げる日」を可視化・突き合わせるため）。Apple カレンダー書込み（下流1）と独立した別シンク。

- **変換**: `~/Developer/form-next-training/src/pool-to-intervals.mjs` — このskillの月JSON `<YYYY-MM>.json` を stdin → intervals.icu events[]。タイトルは `🏊 プール HH:MM-HH:MM`（intervals.icu の import は先頭 `HH:MM` を剥がすバグがあるため、絵文字前置＋ASCIIハイフンで時刻を保持）。
- **投入**: `~/Developer/form-next-training/src/push-intervals.sh` — `external_id=meguro-<date>-<HHMM>` で upsert（＝月次洗い替えと冪等。重複しない）。`.env` に `INTERVALS_API_KEY` / `INTERVALS_ATHLETE_ID`。
- **月次手順に追加**: 月JSONを書いたら `cd ~/Developer/form-next-training && set -a; . .env; set +a; node src/pool-to-intervals.mjs < ~/.claude/scripts/meguro-pool/<YYYY-MM>.json | src/push-intervals.sh`。
- **関連**: プロジェクト `form-next-training`（FORMゴーグルの次トレ→intervals.icu同期）。canonical手順は Scrapbox tkgshn-private「iOSアプリの内部APIをmitmproxyでリバースエンジニアリングする手順 (FORM Swim実例)」。
