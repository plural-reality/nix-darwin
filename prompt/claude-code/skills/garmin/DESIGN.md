# Garmin skill — 設計 (CLI先行版)

## ゴール (確定スコープ)
- このMac上で動く、**Claude Code + Codex 両対応**の Garmin skill。
- **GarminDB による全履歴 SQLite**（sleep/stress/RHR/HRV/weight/activities/monitoring）。
- スマホ/Claude Desktop 対応の常時稼働 bridge(MCP) は **当面作らない**（後日 Phase B）。

## 実機で確定した事実 (2026-06-01 検証済み)
- 認証情報 `takagishunsuke1129@gmail.com` は**有効**、**MFAなし**。
- `garth` はGarminのCloudflare TLSフィンガープリント導入で deprecated。
  → **ブラウザUA上書きで garth の login は今も通る**ことは確認したが、恒久版は使わない。
- 薄いCLIは `garminconnect==0.3.8`、GarminDBは `3.8.0` に固定。GarminDBが内包する
  `garminconnect==0.3.3` と実装版は分かれるが、交換するDI tokenstore schemaは同じ。
- `garminconnect.Client.dumps() -> str`（セッション状態のJSON文字列）が**トークンの単一値**。
  `login(tokenstore_path)`はrefresh後のrotated tokenを同じパスへdumpする。
- GarminDBのauth adapterはtoken fileがあればパスワード不要。wrapperはcredentialを除いた
  一時config directoryを渡し、失敗時のpassword fallback/MFA待ちを構造的に禁止する。

## アーキテクチャ (概念1 / source of truth 1 / 境界1)
```
          personal profileのwritable SOPS source ← 唯一の canonical value
                    garmin_tokens = dumps()       （平文passwordは保存しない）
                          │  with-garmin-token (唯一の復号/writeback境界)
            ┌─────────────┴───────────────┐
   scripts/garmin.py(薄client)        scripts/garmindb-sync
   temp token path→load/dump          同じtemp config/token pathを使用
   activities/activity/fit/...        garmindb_cli --all --download --import --analyze
        │                                   │
   Claude Code CLI / Codex CLI         全履歴 SQLite (~/HealthData, ~/.GarminDb/*.db)
```
- `scripts/with-garmin-token`が唯一の復号/writeback境界。SOPSから0600の一時tokenstoreへ復号し、
  refresh後のrotated tokenを変更時だけSOPSへwritebackして一時平文を削除する。
- `garmin auth`も同じ境界内で一時tokenstoreを置換するだけで、独自のSOPS writerを持たない。
- `lockf`で全consumerを直列化し、refresh token rotationの競合とstale writeを防ぐ。
- skill本体はzero-password。パスワード/MFAは`garmin auth`の端末プロセスだけに存在する。
- 初回またはrevoke時だけemail+password、要求された場合はMFAを対話入力する。以降はtokenのみ。

## ライブラリ実行 (hermetic)
- CLI/GarminDBの版はwrapperで固定し、未固定の`uv run --with`によるdriftを防ぐ。
- Garmin SSO の **429 はクライアントUA/レート由来**。login をループで叩かない。トークン運用で login 自体をほぼ呼ばない。

## secret 配置の判断
- shared skillはinterfaceだけを持ち、暗号済みconcrete value/pathは **personal.nix** がbindする。
- `GARMIN_SECRET`はwritableなSOPS sourceを指す。Nix store内のskill ZIPやread-onlyの
  sops-nix materializationをsource of truthにしない。
- SOPS age recipient は個人profile側で決める。プロジェクトKMSではない。

## 後日 Phase B (スマホ/Desktop)
- 同じ garminconnect ロジックを1プロセスの bridge に包み、MCP-over-HTTP + JSON の2トランスポートで公開。
- 常時稼働ホストは EC2(既存・確実) を第一候補。Mac mini はスリープのため非推奨。
- skill は bridge URL への薄clientへ degrade。スマホは Remote MCP connector として同一 bridge を叩く。
