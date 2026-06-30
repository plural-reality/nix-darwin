---
name: apple-calendar
description: Apple カレンダーにイベントを「正しく」追加・更新するための唯一の窓口。必ず iCloud(=iPhone同期)・位置情報つき(タップでAppleマップ)・時刻指定で入れる。トリガー: 「カレンダーに追加」「予定を入れて」「カレンダー登録」「add to calendar」、および他スキルからのカレンダー書込み委譲。
---

# apple-calendar — Apple カレンダー書込みの唯一の窓口

Claude / Codex が Apple カレンダーにイベントを追加・更新するときは **必ずこのスキル(＝下の `apply.swift`)を通す**。直接 osascript でイベントを作らない（位置情報の座標ピンを付けられず、新規カレンダーが On My Mac に落ちて iPhone 同期しないため）。

## 不変の契約（必ず守る）
1. **iCloud に入れる** — 新規カレンダーは iCloud(CalDAV)ソースに作る。On My Mac は iPhone と同期しない。`apply.swift` が自動でそうする。
2. **位置情報を必ず入れる** — `location`(または `defaultLocation`)を付ける。`address` を書けば `apply.swift` が Apple geocoder で座標化し `EKStructuredLocation.geoLocation` に入れる＝**iPhoneでタップ→Appleマップ**。座標が分かっていれば `lat`/`lon` を直接渡す（geocode省略）。場所が本当に無いイベントのみ location 省略可。
3. **時刻指定**（`start`/`end` を ISO で）。終日にしない。
4. **mode** で洗い替えか追記かを選ぶ。

## 使い方
1. 汎用イベントJSONを組み立てて一時ファイルに Write（schema 下記）。
2. `swift ~/.claude/scripts/calendar/apply.swift <events.json>`（`-` で stdin も可）。
3. 出力 `applied N / removed M / mode=… / source=iCloud` を確認（source が iCloud であること）。

## 汎用イベントJSON schema
```json
{
  "calendar": "カレンダー名",
  "mode": "append",                         // append | replace-month | replace-range
  "year": 2026, "month": 6,                 // replace-month の削除窓
  "rangeStart": "2026-06-01T00:00",          // replace-range の削除窓
  "rangeEnd": "2026-07-01T00:00",
  "defaultLocation": { "title": "場所名", "address": "東京都…", "lat": 35.6, "lon": 139.7 },
  "events": [
    { "title": "イベント名",
      "start": "2026-06-07T18:00", "end": "2026-06-07T22:00",
      "notes": "メモ", "url": "https://…",
      "alarms": [60, 1440],                                     // start からの「分前」通知リスト(省略可)
      "location": { "title": "個別の場所", "address": "…" } }   // 省略時 defaultLocation
  ]
}
```
- `start`/`end` は `yyyy-MM-ddTHH:mm`（ローカル時刻、秒付きも可）。
- `location`/`defaultLocation`: `lat`/`lon` 省略時は `address` を geocode。`title` は地図ピンの名称。
- `alarms`: `start` からの分前(例 `60`=1時間前, `1440`=1日前, `7200`=5日前)。複数指定で複数通知。省略可。
- 単発追加は `mode: "append"`、月次の洗い替えは `replace-month`、任意期間の貼り替えは `replace-range`。

## mode の指針
- **単発予定**（打ち合わせ・予約など）: `append`。同じ予定の二重登録に注意（必要なら先に確認）。
- **定期洗い替え**（外部ソースから当月分を貼り直す等）: `replace-month` / `replace-range`。冪等。

## 消費者（このスキルに依存している例）
- `meguro-pool-update`（プールPDF→往復コースルール→この schema→ apply.swift）。新しいカレンダー自動化も同様にこの窓口へ委譲する。

## いつ「カレンダーでない」か（兄弟バックエンド）
時間で起こる予定はここ。**やること(タスク)で場所がトリガー**なら別バックエンド。判断は `remind-or-schedule`(ルーター)に従う:
- 特定の場所に着いたら通知（この支店/駅, 少数） → `apple-reminders-geofence`（ジオフェンス・リマインダー）
- カテゴリのどこかに近づいたら（どこかの郵便局/プール, 多数） → geo-reminder アプリ
- 時刻だけのタスク通知 → Apple Reminders（時刻）
「この日時に・この場所で」＝カレンダー（位置つき）。「近づいたら」＝リマインダー側。両方欲しければ併用可。
