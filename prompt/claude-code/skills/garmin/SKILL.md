---
name: garmin
description: >-
  Garmin Connect のアクティビティ・睡眠・ストレス・body battery・HRV・training readiness
  を取得し、.fit 生データをダウンロード＆解析する。トリガー: 「Garmin」「ガーミン」
  「今日のラン/ライド」「直近のアクティビティ」「睡眠」「ストレス」「body battery」
  「HRV」「training readiness」「.fitを見て」「アクティビティのデータ」「走行ログ」
  など、自分の Garmin の健康・運動データに関する相談。
---

# Garmin skill

自分の Garmin Connect データをターミナルから取得する薄いクライアント。
認証は **canonical トークン1つ**（`secrets/garmin.enc.yaml` を SOPS 復号 → `GARMINTOKENS`）。
パスワードは保存していない。スクリプト自体は credential を一切知らない。

## 使い方

すべて `scripts/garmin <subcommand> [args]` を実行する。出力は **JSON (stdout)**。
日付は `YYYY-MM-DD`、省略時は今日。

```
scripts/garmin recent [n]          # 直近n件のアクティビティ要約 (default 10)
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
scripts/garmin raw <connectapi-path>  # 任意の Connect API パス GET (escape hatch)
# --- 書き込み (write; read と同じ canonical トークンで実行) ---
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
取り込む（同じ canonical トークンを一時 materialize して使用、パスワード不要）。
初回は重い・長い。`scripts/garmindb-sync --latest` で増分更新。

## 設計・運用メモ

- ライブラリは **garminconnect**（curl_cffi, garth非依存）1本。`uv run --with` で hermetic 実行。
- Garmin SSO は 429 が出やすいので **login をループで叩かない**。トークン運用で login はほぼ不要。
- トークン失効時（パスワード変更等）のみ再生成: `scripts/mint_token.py` を
  `GARMIN_EMAIL`/`GARMIN_PASSWORD`/`GARMIN_TOKEN_OUT` 付きで実行 →
  出力を `GARMINTOKENS` として `sops -e secrets/garmin.enc.yaml` に再封入。
- 詳細な設計判断は `DESIGN.md`。スマホ/Desktop 対応(bridge/MCP)は Phase B（未着手）。
- Codex でも同じ skill body が `~/.agents/skills/garmin/` から使える（symlink）。
