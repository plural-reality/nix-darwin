# SOPS migration — SCRAPBOX_SID / GEMINI_API_KEY

Status: **DONE (2026-07-05)** — activated with an architecture correction. 2026-06-22 の当初計画は
「SID も SOPS へ」だったが、実装時に SID の性質(静的シークレットではなく回転するセッション cookie)
に合わせて設計を修正した。

## Final architecture

| Secret | 正本 (canonical) | 消費経路 | 平文の置き場所 |
|---|---|---|---|
| `SCRAPBOX_SID` | **ログイン済み Chrome セッション**(cookie) | `scrapbox-sid-refresh.sh` が復号→`/api/users/me` 検証→ `~/.claude/settings.local.json`(0600) へ自己修復注入。`cosense-fetch` / `scrapbox-write` / `scrapbox-rename` は env → settings.local.json → self-heal の順で実行時解決 | settings.local.json のみ(runtime cache・0600・nix 外) |
| `GEMINI_API_KEY` | **`secrets.yaml` (SOPS/age)** | 消費側(`gemini-image`)が env 未設定時に `sops decrypt --extract` で実行時復号 | なし |

SID を SOPS に入れなかった理由: SID は失効・回転するため、SOPS に固定すると「第2の古い正本」になり
self-heal(Chrome cookie 由来)と二重管理になる。canonical source of truth は1つ —
静的シークレットは secrets.yaml、セッション cookie は Chrome。

## What was removed (the leak paths)

- `modules/base.nix` `home.sessionVariables.SCRAPBOX_SID`(**公開 repo に平文コミット**、かつ
  world-readable な /nix/store の settings.json へ投影されていた)→ 削除。
- `modules/claude-code.nix` `sharedAgentEnvNames` から `SCRAPBOX_SID` → 削除
  (settings.json / codex config.toml への投影が止まる)。
- `~/.claude/settings.local.json` の `env.GEMINI_API_KEY` → 削除(SOPS へ)。
- `~/.codex/config.toml` の `GEMINI_API_KEY` / `SCRAPBOX_SID` 平文 → 削除。

## Rotation record

- 漏洩していた旧 SID セッション(`s:SHE-0nIW…`、base.nix にコミットされていたもの)は
  2026-07-05 に CSRF 付き `POST https://scrapbox.io/logout` で**失効済み**(`/api/users/me` が
  `isGuest:true` を返すことを実測確認)。現用セッション(Chrome 由来)は無事。
- `GEMINI_API_KEY` は現行値を SOPS へ移設。**ローテーション(AI Studio で再発行)は未実施** —
  過去に平文でディスク/repo に存在した期間があるため、気になるなら再発行して
  `sops set secrets.yaml '["gemini_api_key"]' '"<new>"'` で差し替える(消費側は無変更で追従)。

## Note on git history

base.nix の平文 SID は git 履歴には残っている(HEAD からは除去済み・セッション自体は失効済みなので
実害はない)。履歴スクラブは費用対効果が低いので不要([[reference_git_history_scrub_gotchas]])。
