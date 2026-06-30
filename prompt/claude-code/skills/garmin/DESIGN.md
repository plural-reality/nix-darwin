# Garmin skill — 設計 (CLI先行版)

## ゴール (確定スコープ)
- このMac上で動く、**Claude Code + Codex 両対応**の Garmin skill。
- **GarminDB による全履歴 SQLite**（sleep/stress/RHR/HRV/weight/activities/monitoring）。
- スマホ/Claude Desktop 対応の常時稼働 bridge(MCP) は **当面作らない**（後日 Phase B）。

## 実機で確定した事実 (2026-06-01 検証済み)
- 認証情報 `takagishunsuke1129@gmail.com` は**有効**、**MFAなし**。
- `garth` はGarminのCloudflare TLSフィンガープリント導入で deprecated。
  → **ブラウザUA上書きで garth の login は今も通る**ことは確認したが、恒久版は使わない。
- **canonical ライブラリ = `garminconnect` 0.3.3**（`curl_cffi` ネイティブ認証、garth非依存）。
  GarminDB v3.8.0 も `garminconnect==0.3.3` 依存なので**ライブラリは1本に統一**。
- `garminconnect.Client.dumps() -> str`（セッション状態のJSON文字列）が**トークンの単一値**。
  `login(tokenstore)` は `GARMINTOKENS` env を読み、512文字超なら文字列として直接 `loads()`。
- GarminDB の auth adapter は**トークンファイルがあればパスワード不要**で login（無い時だけ user/pass フォールバック）。token store = `~/.GarminDb/garmin_tokens.json`（単一JSONファイル）。

## アーキテクチャ (概念1 / source of truth 1 / 境界1)
```
                 secrets/garmin.enc.yaml   ← 唯一の canonical secret (SOPS, 個人ageキー)
                   GARMINTOKENS = dumps()      （平文passwordは保存しない）
                          │  sops exec-env  (唯一の復号境界)
            ┌─────────────┴───────────────┐
   scripts/garmin.py(薄client)        scripts/garmindb-sync
   GARMINTOKENS env→loads()           GARMINTOKENS→~/.GarminDb/garmin_tokens.json に materialize
   activities/activity/fit/...        garmindb_cli --all --download --import --analyze
        │                                   │
   Claude Code CLI / Codex CLI         全履歴 SQLite (~/HealthData, ~/.GarminDb/*.db)
```
- **secret は env(`GARMINTOKENS`) として `sops exec-env` で注入** → ディスクに平文トークンを置かない（GarminDB実行時のみ token file を一時 materialize）。
- skill 本体は **zero-credential**。トークンもemailも知らず、復号は `sops exec-env` の1行だけ。
- 初回1回だけ email+pass+MFA(無し) でトークン生成 → 以降トークンのみ。Garmin がトークンを revoke した時(パスワード変更/失効)だけ再mint。

## ライブラリ実行 (hermetic)
- グローバルを汚さず `uv run --with garminconnect`（後で Nix flake 化）。
- Garmin SSO の **429 はクライアントUA/レート由来**。login をループで叩かない。トークン運用で login 自体をほぼ呼ばない。

## secret 配置の判断
- Garmin トークンは**個人クレデンシャル** → `baisoku-survey`(プロジェクトKMS) ではなく**個人ageキー**で暗号化し skill フォルダに同梱。
- interface(skill) と secret を1箇所に。nix-darwin に publish する際は **個人レイヤ(personal.nix)**へ。base(共有)には入れない。

## 後日 Phase B (スマホ/Desktop)
- 同じ garminconnect ロジックを1プロセスの bridge に包み、MCP-over-HTTP + JSON の2トランスポートで公開。
- 常時稼働ホストは EC2(既存・確実) を第一候補。Mac mini はスリープのため非推奨。
- skill は bridge URL への薄clientへ degrade。スマホは Remote MCP connector として同一 bridge を叩く。
