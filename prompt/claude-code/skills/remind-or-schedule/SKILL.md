---
name: remind-or-schedule
description: 「覚えておきたい/思い出したい/予定を入れたい/近づいたら通知してほしい」意図を、時間か場所かのトリガーで判断し、適切なバックエンド(カレンダー / 場所リマインダー / カテゴリ近接アプリ)へ振り分ける単一の窓口。トリガー: 「リマインド」「覚えておいて」「通知して」「予定入れて」「〜したら教えて」「〜の近くに行ったら」「remind me」「schedule」「notify me when near」。
---

# remind-or-schedule — 「時 か 場所 で再浮上させる」意図のルーター

ユーザーの「あとで思い出したい/予定にしたい」意図は、**トリガーの種類**で最適なバックエンドが決まる。3つは同じ根（意図を正しい *時* か *場所* で再浮上させる）の別実装。このスキルは intent → backend の振り分けだけを担い、実際の書込みは各バックエンドに委譲する。

## 判断マトリクス（これに従って振り分ける）

```
Q1. 決まった日時に「起こる/ある」ものか？(会議・予約・開館枠・締切イベント)
      → YES: カレンダーイベント …………… apple-calendar
Q2. 「やること(タスク)」で、トリガーは？
   (a) 時刻・期日で通知したい …………………… 時刻リマインダー (Apple Reminders, due)
   (b) 特定の場所に着いたら(この支店/駅/店, 少数 ≤20) → ジオフェンス … apple-reminders-geofence
   (c) カテゴリのどこかに近づいたら(どこかの郵便局/プール/ダイソー, 多数) → geo-reminder アプリ
```

判断の軸は2つだけ: **時間 vs 場所**、(場所なら)**特定地点 vs カテゴリ**。迷ったら下の境界例とユーザー確認。

## 各バックエンドへの委譲

### A. カレンダー（時間で起こる）→ [apple-calendar]
- 使う時: 会議/予約/イベント、開館・営業の「枠」、締切そのものを時間ブロックで置きたい。
- 委譲: `apple-calendar` スキル＝`swift ~/.claude/scripts/calendar/apply.swift <json>`。**iCloud固定・位置情報必須・時刻指定**はそちらが担保。
- 例: 「来週火曜15時に田中さんと打ち合わせ(渋谷)」「目黒区民プールの個人利用枠」。

### B. 場所リマインダー（特定地点に着いたら）→ [apple-reminders-geofence]
- 使う時: 「この銀行に寄ったら/この郵便局の前を通ったら〜する」など**少数の特定地点**(iOS同時ジオフェンス上限 ≈20)。
- 委譲: `apple-reminders-geofence` スキル＝`swift ~/.claude/skills/apple-reminders-geofence/scripts/geofence_reminders.swift < spec.json`（marker冪等・proximity=enter・既定リスト iCloud「Everything」）。座標は explicit、半径は行動境界から(150-250m建物/300-550m徒歩圏)。
- 時刻だけのリマインダー(場所なし)もここ（Apple Reminders の due）。

### C. カテゴリ近接（どこかの◯◯に近づいたら）→ [project_geo_reminder_app]（geo-reminder アプリ）
- 使う時: 「**どこか**の郵便局/プール/ダイソーに近づいたら」のように**地点が無数**で、特定の1点でなくカテゴリ。Apple の20件上限を超える/カテゴリで指定したい。
- **連携方針(現状)**: ルーターは「これは geo-reminder 向き」と**判断・説明まで**。実投入は手動/アプリ（アプリは実機ビルド未完。データ層 Supabase `tasks` ref `xirsponjosfhbddcimgp` は稼働、`supabase` CLI でカテゴリ行を upsert すれば拾える）。自動投入はユーザーが望めば別途。

## 境界例・確認の指針
- **時間 と 場所 の両方**: 例「プール開館枠」は時間予定＝カレンダー(位置も入れて地図対応)。「どこかのプールに寄ったら泳ぐ準備を思い出す」はカテゴリ近接＝geo-reminder。両方欲しい(=この日時にこの場所で、かつ近づいたら通知)なら、カレンダー＋場所リマインダーを**両方**作ってよい（重複と感じるなら確認）。
- **特定地点が多数(>~20)**: B(ジオフェンス)は上限に当たる → C(カテゴリ)へ寄せるか、エリア×時間で動的入替（[apple-reminders-geofence] の運用）。
- どちらとも取れる短い指示は、時間が明示されていれば A、場所が主語なら B/C を既定にしつつ、曖昧なら一言確認する。

## 共通の前提
- いずれも **iCloud** に書く＝iPhone同期。位置を伴うものは座標つき（カレンダーは住所→geocode自動、リマインダーは座標 explicit）。
- canonical: カレンダー → [reference_apple_calendar_primitive] / 場所リマインダー → [reference_geofence_reminders] / カテゴリ → [project_geo_reminder_app]。
