---
name: apple-calendar
description: Apple カレンダーにイベントを「正しく」追加・更新するための唯一の窓口。必ず iCloud(=iPhone同期)・位置情報つき(タップでAppleマップ)・時刻指定で入れる。トリガー: 「カレンダーに追加」「予定を入れて」「カレンダー登録」「add to calendar」、および他スキルからのカレンダー書込み委譲。
---

# apple-calendar — Apple カレンダー書込みの唯一の窓口

Claude / Codex が Apple カレンダーにイベントを追加・更新するときは **必ずこのスキル(＝下の `evkit calendar`)を通す**。直接 osascript でイベントを作らない（位置情報の座標ピンを付けられず、新規カレンダーが On My Mac に落ちて iPhone 同期しないため）。

**`swift apply.swift` を直接叩かない。** TCC はカレンダー許可を「責任プロセスの code identity」に紐づけるため、Claude Code から直接叩くと許可が claude のバージョン付きパスに付き、更新のたびに失効する。さらに SSH/tmux は Aqua セッションでないので許可ダイアログを描画できず自動拒否される。`evkit` は MacBook Air 常駐の署名済みヘルパー `evkitd` に委譲するので、どのホスト・どのセッションからでも通る。`apply.swift` はその evkitd が exec する実装であり、呼び出し口ではない。

## 不変の契約（必ず守る）
1. **既存の iCloud にだけ入れる** — `calendarId` は EventKit の stable ID。`apply.swift` はそのIDで既存の iCloud(CalDAV)カレンダーだけを解決し、未発見なら失敗する。名前一致で新規カレンダーを作らない。新しいカレンダーは Calendar.app で明示作成してからIDを取得する。On My Mac は iPhone と同期しない。
2. **位置情報を必ず入れる** — `location`(または `defaultLocation`)を付ける。`address` を書けば `apply.swift` が Apple geocoder で座標化し `EKStructuredLocation.geoLocation` に入れる＝**iPhoneでタップ→Appleマップ**。座標が分かっていれば `lat`/`lon` を直接渡す（geocode省略）。場所が本当に無いイベントのみ location 省略可。
3. **時刻指定**（`start`/`end` を ISO で）。終日にしない。
4. **mode** で洗い替えか追記かを選ぶ。

## 使い方
1. 汎用イベントJSONを組み立てて一時ファイルに Write（schema 下記）。
2. `evkit calendar < events.json`
3. 返る JSON の `ok` が true で、`stdout` が `applied N / removed M / mode=… / source=iCloud` であることを確認（source が iCloud であること）。

`ok:false` かつ `calendar access not granted` が返ったら、TCC 許可が剥がれている。MacBook Air の画面で
システム設定 → プライバシーとセキュリティ → カレンダー → **EventKitBridge** をフルアクセスにする（原則一度きり）。
Air がスリープ／到達不能なら ssh が失敗する。これは正しい失敗であり、黙って別経路に落ちてはいけない。

## 汎用イベントJSON schema
```json
{
  "calendarId": "EventKit calendarIdentifier",
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

新規の呼出元は必ず `calendarId` を渡す。移行中の既存自動化だけは `calendar` 名を渡せるが、**既存の iCloud カレンダーへの完全一致に限る**。存在しなければ失敗し、新規作成はしない。
- `start`/`end` は `yyyy-MM-ddTHH:mm`（ローカル時刻、秒付きも可）。
- `location`/`defaultLocation`: `lat`/`lon` 省略時は `address` を geocode。`title` は地図ピンの名称。
- `alarms`: `start` からの分前(例 `60`=1時間前, `1440`=1日前, `7200`=5日前)。複数指定で複数通知。省略可。
- 単発追加は `mode: "append"`、月次の洗い替えは `replace-month`、任意期間の貼り替えは `replace-range`。

## mode の指針
- **単発予定**（打ち合わせ・予約など）: `append`。同じ予定の二重登録に注意（必要なら先に確認）。
- **定期洗い替え**（外部ソースから当月分を貼り直す等）: `replace-month` / `replace-range`。冪等。

## 消費者（このスキルに依存している例）
- `meguro-pool-update`（プールPDF→往復コースルール→この schema→ `evkit calendar`）。新しいカレンダー自動化も同様にこの窓口へ委譲する。

## 層の分担（どこに何が住むか）
| 層 | 実体 | 責務 |
|---|---|---|
| client | `evkit`（PATH） | spec を包んで Air のソケットへ流すだけ。TCC 権限不要。mini からは ssh で縮退 |
| 権限境界 | `evkitd`（署名済み `EventKitBridge.app`, Air の LaunchAgent） | TCC の責任プロセス。許可を恒久保持し、実装を exec する |
| 実装 | `apply.swift` | iCloud固定・geocode・mode の「正しさ」。ここが canonical |

## いつ「カレンダーでない」か（兄弟バックエンド）
時間で起こる予定はここ。**やること(タスク)で場所がトリガー**なら別バックエンド。判断は `remind-or-schedule`(ルーター)に従う:
- 特定の場所に着いたら通知（この支店/駅, 少数） → `apple-reminders-geofence`（ジオフェンス・リマインダー）
- カテゴリのどこかに近づいたら（どこかの郵便局/プール, 多数） → geo-reminder アプリ
- 時刻だけのタスク通知 → Apple Reminders（時刻）
「この日時に・この場所で」＝カレンダー（位置つき）。「近づいたら」＝リマインダー側。両方欲しければ併用可。
