---
name: garmin
description: >-
  Garmin Connect のアクティビティ・睡眠・ストレス・body battery・HRV・training readiness
  と構造化ワークアウトを取得・日付指定し、.fit 生データをダウンロード＆解析する。トリガー: 「Garmin」「ガーミン」
  「今日のラン/ライド」「直近のアクティビティ」「睡眠」「ストレス」「body battery」
  「HRV」「training readiness」「.fitを見て」「アクティビティのデータ」「走行ログ」
  など、自分の Garmin の健康・運動データに関する相談。
---

# Garmin skill

自分の Garmin Connect データをターミナルから取得する薄いクライアント。
認証は **canonical トークン1つ**（personal profileがbindしたwritable SOPS sourceの
`garmin_tokens`を一時tokenstoreへ復号）。shared skillは具体的なsecretを含みません。
パスワードは保存していない。スクリプト自体は credential を一切知らない。

## 使い方

すべて `scripts/garmin <subcommand> [args]` を実行する。出力は **JSON (stdout)**。
日付は `YYYY-MM-DD`、省略時は今日。

```
scripts/garmin recent [n]          # 直近n件のアクティビティ要約 (default 10)
scripts/garmin auth                # 対話再認証 → rotating tokenをSOPSへ保存
scripts/garmin last                # 最新アクティビティ要約
scripts/garmin activity <id>       # アクティビティ詳細
scripts/garmin details <id>        # 詳細(時系列メトリクス込み)
scripts/garmin splits <id>         # ラップ/スプリット
scripts/garmin weather <id>        # 天候
scripts/garmin fit <id>            # .fit を ORIGINAL DL → 保存 → garmin-fit-sdk で解析サマリ
scripts/garmin sleep [date]        # 睡眠
scripts/garmin stress [date]       # ストレス
scripts/garmin steps [date]        # 歩数
scripts/garmin hrv [date]          # HRV
scripts/garmin rhr [date]          # 安静時心拍
scripts/garmin bodybattery [s] [e] # body battery (範囲, default 昨日→今日)
scripts/garmin stats [date]        # 日次サマリ統計
scripts/garmin summary [date]      # user summary
scripts/garmin readiness [date]    # training readiness
scripts/garmin status [date]       # training status
scripts/garmin spo2 [date]         # SpO2
scripts/garmin respiration [date]  # 呼吸
scripts/garmin weight [s] [e]      # 体重 (範囲, default 30日)
scripts/garmin devices             # デバイス一覧
scripts/garmin profile             # 氏名/単位系
scripts/garmin workouts [s] [n]    # ワークアウトlibrary (offset, limit)
scripts/garmin workout <id>        # 構造化ワークアウト詳細
scripts/garmin scheduled <y> <m>   # 月別scheduled workout
scripts/garmin scheduled-one <id>  # scheduled workout詳細
scripts/garmin raw <connectapi-path>  # 任意の Connect API パス GET (escape hatch)
# --- 書き込み (write; read と同じ canonical トークンで実行) ---
cat workout.json | scripts/garmin workout-create       # JSON objectをstdinから新規登録
cat workout.json | scripts/garmin workout-update <id>  # 完全なJSON objectで更新
scripts/garmin workout-schedule <id> <YYYY-MM-DD>      # library workoutを日付指定
scripts/garmin workout-unschedule <scheduleId>         # scheduleだけ解除
scripts/garmin workout-push <id> <deviceId>            # 明示deviceへ直接送信
scripts/garmin rename <id> <title>                      # アクティビティ改名
scripts/garmin settype <id> <typeId> <typeKey> <parentTypeId>  # 種別変更 (例: <id> 6 trail_running 1)
scripts/garmin gear <userProfilePk>                     # gear一覧 (filterGear)。pk は socialProfile の profileId
scripts/garmin link <gearUUID> <id>                     # gear をアクティビティに紐付け
scripts/garmin unlink <gearUUID> <id>                   # 紐付け解除
scripts/garmin retire <gearPk|uuid>                     # gear を retire (現DTOを読んで status=retired+dateEnd で PUT)
scripts/garmin post <path> <json>                       # 任意 POST (例 gear 作成: post /gear-service/gear '{...}')
scripts/garmin put  <path> <json>                       # 任意 PUT
scripts/garmin del  <path>                              # 任意 DELETE
scripts/garmin help                # 一覧
```

書き込みの注意:
- workout payloadはargvへ埋め込まずstdinで渡す。`workout-update`は部分patchではなく完全置換として扱う。
- `workout-schedule`後は`scheduled <year> <month>`でConnect上をreadbackする。これはクラウド反映の証拠であり、watch到達はdevice sync後に別確認する。
- `workout-push`は暗黙のlast deviceを選ばず、`devices`で確認した`deviceId`を必ず指定する。
- `settype` の typeId/parentTypeId は `raw /activity-service/activity/activityTypes` で確認（running=1/17, trail_running=6/1）。
- gear の作成は lib に無いため `post /gear-service/gear`。retire/更新の PUT は **gearPk ではなく uuid をパスに使う**（サーバが body.uuid と一致検証する）。`retire` はこれを内部で吸収済み。
- 紐付け系は冪等。アクティビティの「使用ギア」は `raw "/gear-service/gear/filterGear?activityId=<id>"` で確認。

`raw` は上記に無いエンドポイントを叩く抜け道。例:
`scripts/garmin raw /usersummary-service/usersummary/daily/{displayName}?calendarDate=2026-05-31`

## .fit データの参照

`scripts/garmin fit <id>` は zip(ORIGINAL) を取得 → `.fit` を `~/HealthData/FitFiles/skill/<id>.fit`
に保存し、`session`(sport/distance/HR/標高)・`record_mesgs` 件数・メッセージ型別カウントを返す。
保存済み `.fit` を再解析したい場合は `garmin-fit-sdk` の `Stream.from_file(path)` を使う。

## 全履歴 (GarminDB)

直近のライブ取得とは別に、全履歴 SQLite は `scripts/garmindb-sync` が
`~/.GarminDb` / `~/HealthData` に sleep/stress/RHR/HRV/weight/activities/monitoring を
取り込む（同じ ephemeral tokenstoreを使用、パスワード不要）。
初回は重い・長い。`scripts/garmindb-sync --latest` で増分更新。

## 設計・運用メモ

- 薄いCLIは **garminconnect 0.3.9**、GarminDBは **3.8.0** を固定。後者が
  `garminconnect 0.3.3` を内包するが、共有するDI tokenstore schemaは同じ。
- `scripts/with-garmin-token` が唯一の復号/writeback境界。SOPSを0600一時tokenstoreへ
  復号し、refreshでrotated tokenが変わった時だけSOPSへ戻し、平文を削除する。
- concrete bindingはpersonal Home Managerの`GARMIN_SECRET`。Nix store内のskillや
  read-only sops-nix materializationへはwritebackしない。
- `lockf`でCLIとGarminDBを直列化し、refresh token rotationの競合を防ぐ。
- Garmin SSO は 429 が出やすいので **login をループで叩かない**。トークン運用で login はほぼ不要。
- refresh token失効時（パスワード変更等）のみ `scripts/garmin auth`。パスワード/MFAは
  その端末で対話入力し、保存しない。成功したDI tokenだけSOPSへ保存する。
- 詳細な設計判断は `DESIGN.md`。スマホ/Desktop 対応(bridge/MCP)は Phase B（未着手）。
- Codex でも同じ skill body が `~/.agents/skills/garmin/` から使える（symlink）。
