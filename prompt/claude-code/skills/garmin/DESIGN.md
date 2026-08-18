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
     ~/.local/state/garmin/tokens.json ← ホストごとの唯一の canonical value
              0600 / dumps()の文字列        （平文passwordは保存しない）
                          │  with-garmin-token (唯一の読み書き境界)
            ┌─────────────┴───────────────┐
   scripts/garmin.py(薄client)        scripts/garmindb-sync
   temp token path→load/dump          同じtemp config/token pathを使用
   activities/activity/fit/...        garmindb_cli --all --download --import --analyze
        │                                   │
   Claude Code CLI / Codex CLI         全履歴 SQLite (~/HealthData, ~/.GarminDb/*.db)
```
- `scripts/with-garmin-token`が唯一の読み書き境界。host-local storeを0600の一時tokenstoreへ
  複製し、refresh後のrotated tokenを変更時だけatomic renameで書き戻して一時平文を削除する。
- `garmin auth`も同じ境界内で一時tokenstoreを置換するだけで、独自のwriterを持たない。
  storeが無い状態が bootstrap ケースで、初回tokenも同じ境界を通って書かれる。
- `lockf`で全consumerを直列化し、refresh token rotationの競合とstale writeを防ぐ。
- skill本体はzero-password。パスワード/MFAは`garmin auth`の端末プロセスだけに存在する。
- 初回またはrevoke時だけemail+password、要求された場合はMFAを対話入力する。以降はtokenのみ。

## ライブラリ実行 (hermetic)
- CLI/GarminDBの版はwrapperで固定し、未固定の`uv run --with`によるdriftを防ぐ。
- Garmin SSO の **429 はクライアントUA/レート由来**。login をループで叩かない。トークン運用で login 自体をほぼ呼ばない。

## secret 配置の判断
- rotating token と configuration secret は別のものなので、別の場所に置く。`secrets.yaml`
  のような git 追跡下の SOPS store に混ぜると、checkout が恒久的に dirty になり、
  ホスト間で ciphertext が conflict し、内容のない churn コミットが要る運用に落ちる。
- storeは平文0600。復号鍵が同じディスクに平文で置かれる以上、ここでの暗号化は防御にならない。
  境界自体もコマンド実行のたびに平文を materialize している。
- パスは shared skill 側の既定値で閉じる。personal.nix はGarmin tokenのパスを知らない
  （知る主体が増えるほど、その知識が食い違う場所が増える）。
- ホストごとに独立した系統を持つ。共有すると refresh 時に互いの世代を無効化しうる。

## 後日 Phase B (スマホ/Desktop)
- 同じ garminconnect ロジックを1プロセスの bridge に包み、MCP-over-HTTP + JSON の2トランスポートで公開。
- 常時稼働ホストは EC2(既存・確実) を第一候補。Mac mini はスリープのため非推奨。
- skill は bridge URL への薄clientへ degrade。スマホは Remote MCP connector として同一 bridge を叩く。
