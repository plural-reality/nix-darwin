---
name: apple-calendar
description: >
  本人の予定・空き時間をApple Calendarから確認し、許可されたイベントを既存iCloudカレンダーへ追加・更新する。
  「いつ空いてる」「予定確認」「予定を入れて」「カレンダーに追加」で使う。締切つきのやることはremind-or-scheduleへ。
---

# apple-calendar — 対象を解決してから読み書きする

予定の存在、本人の参加・対応責任、完了を分ける。他人の予定や「仮」のラベルだけから本人の予定を確定しない。
読取は `evkit snapshot`、既存iCloudへの書込は `evkit calendar`。法人Googleへの書込は `gws calendar` に分岐する。

## 本人の予定・空き時間を読む

1. Google Calendarだけで判断せず、Apple Calendar側も読む。`evkit calendar.catalog` で現在のID・表示名・source・writableを確認し、本人が指定した対象を解決する。表示名は改名されるため、既知のstable IDとsourceを優先する。同名の共有用を選ばない。
2. 本人の個人予定（旧表示名 `Taka の予定`、現在の候補名 `個人予定`）、本人の法人・個人Google、ルーティーン、トレーニング計画、祝日を対象にする。対象のbindingは本人の最新指定と現catalogに照合する。旧 `Business` や旧トレーニング名が存在すると決め打ちしない。
   共有の `Univ` / `勤務先` / `Personal` / `Exercise` / `惟の居住地` / `目黒区民プール` / `Yui` / `Ryu` 等は他人・施設の予定であり、本人の空き判定に混ぜない。トレーニング計画は可動枠、祝日や施設枠は拘束予定と区別する。
3. 必要な期間と解決済みIDに絞ってsnapshotを取得する。両selectorの `names` と `ids` は省略しない。名前とIDはOR条件なので、IDが分かるなら名前は空にする。

```json
{
  "rangeStart": "2026-09-07T00:00:00+09:00",
  "rangeEnd": "2026-09-08T00:00:00+09:00",
  "calendars": {"names": [], "ids": ["解決済み本人カレンダーID"]},
  "reminderLists": {"names": [], "ids": []}
}
```

`evkit snapshot < snapshot.json` は開始を含み終了を含まない範囲で読む。offset・秒付きISO 8601を使う。
`ok`、`partial`、`errors.events` と `containers.calendars` を確認する。期待IDが未解決なら **eventsが空でも「予定なし」ではない**。catalogと対象指定を見直す。必要な本人カレンダーが欠けている時は空き判定を確定しない。

## 書込先と副作用

- **既存iCloudだけ**: catalogで確定した `calendarId` を渡す。`calendar` 名前指定はlegacy fallbackなので新規specには併記しない。現writerはカレンダーを新規作成せず、未知ID・非iCloudを拒否する。
- **法人Google**: 本人の法人アカウントと対象Calendar IDを確認し `gws calendar` の既存経路を使う。個人iCloudへの代替保存、同一予定の二重登録はしない。
- **位置・時刻**: `start` / `end` はローカル `yyyy-MM-ddTHH:mm`（秒付きも可）、終日にしない。実際の場所がある予定には `location` / `defaultLocation` を付ける。住所はgeocode、既知なら座標を指定する。場所のないオンライン予定等に架空の住所を付けない。
- **変更範囲**: 単発は重複確認後 `append`。`replace-month` / `replace-range` は対象Calendarの指定期間を洗い替えるため、その削除範囲を含む依頼に限る。個別予定の修正目的で無関係な予定まで洗い替えない。

```json
{
  "calendarId": "catalogで解決した既存iCloud ID",
  "mode": "append",
  "defaultLocation": {"title": "場所名", "address": "確認した住所"},
  "events": [{
    "title": "イベント名", "start": "2026-09-07T14:00", "end": "2026-09-07T15:00",
    "notes": "根拠・未確定条件", "url": "https://example.org/event", "alarms": [60]
  }]
}
```

任意の個別 `location` はdefaultを上書きし、`lat` / `lon` も指定できる。`alarms` は開始の何分前か（例60=1時間前）。
洗い替えだけ `year` / `month`、または `rangeStart` / `rangeEnd` を追加する。入力を固定して `evkit calendar < events.json`。

## 検証と停止

- 書込応答の `ok` と `applied N / removed M / mode=… / calendarId=… / source=iCloud` を確認後、対象ID・期間でsnapshotを再取得し、タイトル・開始終了・場所・件数を照合する。応答OKだけで登録済みにしない。
- snapshotが確認できるのは場所文字列等まで。備考・通知・座標ピン・iPhone同期が結果の要件なら、それを確認できる正本表示も必要。snapshotだけでその成功を主張しない。
- `evkit` は署名済み `EventKitBridge` / `evkitd` に委譲する境界。直接 `swift apply.swift` やosascriptで代替しない。許可不足、到達不能、書込・readback失敗は未完了として区別し、黙って別経路へ落とさない。
- 端末の許可設定・認証が必要な時だけ本人に依頼する。TCCエラー以外をすべて権限失効と断定しない。

`meguro-pool-update` 等の消費者もこの入出力契約を使う。場所で発火するタスク・締切タスクは `remind-or-schedule` で振り分ける。
