## 11. 日常運用

ブートストラップ完了後、2 つの実行形態が利用可能になる。ただし deploy pipeline 自体は 1 つであり、違うのは build / activate をどこで実行するかだけである。

### 統一デプロイパイプライン

1. 依存解決
2. NixOS closure の build
3. Cachix への publish
4. activation
5. smoke test + revision 検証
6. failure 時の rollback

ローカル deploy と Self-Deploy の違いは 2-4 の実行場所だけである。Cachix の pre-warm と source filtering は高速化であって前提条件ではない。

### 方法 1: ローカルデプロイ（手動）

ローカルの Nix Builder でビルドし、Cachix 経由で EC2 にデプロイする。

```
Developer Mac
  │
  ├─ nix run .#deploy
  │    ├─ SSH 鍵 / Cachix token を自動解決
  │    ├─ nix build        (ローカルでビルド)
  │    ├─ cachix push      (Cachix に publish)
  │    ├─ colmena apply    (activation)
  │    ├─ smoke test       (SSH 経由)
  │    └─ rollback         (failure 時は remote rollback)
  │
  └─ (フォールバック: nix run .#deploy-ssh)
       ├─ SSH 鍵を自動解決
       ├─ colmena apply    (SSH nix-copy-closure で直接転送)
       ├─ smoke test       (SSH 経由)
       └─ rollback         (failure 時は remote rollback)
```

### 方法 2: Self-Deploy（自動）

main への push やタグ付きリリースに対して、EC2 が自動でデプロイする。
事前の `cachix push` は高速化として有効だが、前提条件ではない。

```
Developer Mac (or CI)
  │
  ├─ (optional) nix build + cachix push  (Cachix を pre-warm)
  ├─ git push (main)          → EC2 staging: webhook
  │                              → colmena apply-local (cache hit 時 pull / miss 時 local build)
  │                              → smoke test
  │                              → Cachix push-back
  │                              → revision verify
  └─ git tag v* + push        → EC2 prod: webhook
                                 → colmena apply-local (staging の push-back で cache hit 可能)
                                 → smoke test
                                 → Cachix push-back
                                 → revision verify
```

`nix run .#deploy` や CI build による Cachix pre-warm は有効だが、Self-Deploy は cache miss でも成立し、成功後に push-back で次回以降を高速化する。

### 開発サイクル一覧

```
┌──────────────────────────────────────────────────────────────┐
│  コード変更 (方法 1):                                         │
│    nix run .#deploy                                           │
│      (依存解決 → build → cachix push → activate → verify)     │
│                                                              │
│  コード変更 (方法 2):                                         │
│    git push → EC2 自動デプロイ                               │
│      (cache hit 時 pull / miss 時 local build → push-back)    │
│    必要なら事前に nix run .#deploy / CI build で pre-warm     │
│                                                              │
│  フォールバック:                                              │
│    nix run .#deploy-ssh                                      │
│      (依存解決 → SSH 転送 → activate → verify)                │
│                                                              │
│  Secret 変更:                                                 │
│    sops edit → git commit → nix run .#deploy                 │
│    または git push → EC2 自動デプロイ                        │
│                                                              │
│  インフラ変更 (既存の開発者なら誰でも実行可能):                │
│    *.tf 編集 → sops exec-env ... -- terraform apply          │
│    → JSON を git commit → nix run .#deploy                   │
│                                                              │
│  開発者の追加・削除 (既存の開発者なら誰でも実行可能):          │
│    locals.tf 編集 → sops exec-env ... -- terraform apply     │
│    → 新メンバーの Access Key を作成して渡す                   │
└──────────────────────────────────────────────────────────────┘
```

### コマンドリファレンス

```bash
# === 方法 1: ローカルデプロイ (デフォルト: Cachix 経由) ===
nix run .#deploy
# → operator key を自動ロード → build → cachix push → colmena apply
# → smoke test + revision verify → failure 時は remote rollback

# === 方法 1: フォールバック (SSH 直接転送) ===
nix run .#deploy-ssh
# → operator key を自動ロード → colmena apply (SSH nix-copy-closure で直接転送)
# → smoke test + revision verify → failure 時は remote rollback

# === 方法 2: Self-Deploy (自動) ===
git push            # webhook が staging self-deploy を発火
git tag v1.2.3
git push --tags     # webhook が production self-deploy を発火

# === Optional: Cachix pre-warm ===
nix run .#deploy    # 先に closure を Cachix に push してもよいが必須ではない

# === Secret 編集 ===
sops secrets/<project>-prod.yaml
# → 保存後に colmena apply で反映

# === インフラ変更 ===
cd infra/terraform
sops exec-env ../../secrets/infra.yaml -- terraform plan   # 確認
sops exec-env ../../secrets/infra.yaml -- terraform apply  # 適用

# === 開発者の追加・削除 (既存の開発者なら誰でも実行可能) ===
cd infra/tfc-bootstrap
sops exec-env ../../secrets/infra.yaml -- terraform apply

# === サーバー接続 ===
# deploy / deploy-ssh の前に SSH 鍵のロードは不要
# 手動 SSH 接続だけ必要な場合のみ:
nix run .#ssh-load   # operator key を agent にロード
ssh <project>-<env>

# === ログ確認 ===
ssh <project>-<env> journalctl -u <project> -f
ssh <project>-<env> journalctl -u nginx -f
ssh <project>-<env> journalctl -u mysql -f

# === サービス状態確認 ===
ssh <project>-<env> systemctl status <project>

# === デプロイされたリビジョン確認 ===
# HTTP 経由 (外部から)
curl -s https://<domain>/.well-known/version | jq
# SSH 経由 (直接)
ssh <project>-<env> cat /etc/nixos-version.json | jq
# NixOS generation (store path)
ssh <project>-<env> readlink /run/current-system
```

---

## 12. 開発者オンボーディング

### 新しい開発者を追加する（既存の開発者なら誰でも実行可能）

全て宣言的。git commit + `terraform apply` で完結する。
既存の開発者は bootstrap 層の IAM / KMS 管理権限を持つため、
初回ブートストラップ後は特別な権限は不要。

```bash
# 1. locals.tf に開発者を追加
cd infra/tfc-bootstrap
# locals.tf を編集:
#   developers = [..., "new-developer"]

# 2. git commit + push
git add locals.tf
git commit -m "Add new developer: new-developer"
git push

# 3. Bootstrap apply (IAM user が自動作成される)
# 既存の開発者の AWS credentials で実行可能
sops exec-env ../../secrets/infra.yaml -- terraform apply

# 4. 新メンバーの初回 Access Key を作成して渡す
aws iam create-access-key \
  --user-name new-developer \
  --output table
# → AccessKeyId と SecretAccessKey を安全な方法で新メンバーに伝達
#   (対面、暗号化メッセージ等。平文メール/Slack は避ける)

# 5. 新メンバーに通知する内容:
#   - IAM username
#   - AccessKeyId / SecretAccessKey
#   - リポジトリ URL
#   - 以下のセットアップ手順
```

### 新メンバーのセットアップ手順

```bash
# 1. リポジトリを clone
git clone <repo-url>
cd <project>

# 2. 既存メンバーから受け取った Access Key で AWS CLI を設定
aws configure
# AWS Access Key ID: <上で取得した値>
# AWS Secret Access Key: <上で取得した値>
# Default region: <region>

# 3. KMS アクセスを確認
aws sts get-caller-identity
sops -d secrets/<project>-prod.yaml > /dev/null && echo "OK: KMS access confirmed"

# 4. SSH config を設定
# (Cachix auth token は deploy スクリプト内で SOPS から自動抽出される。手動設定不要)
# IdentityFile は不要 — ssh-agent が鍵を保持する
cat >> ~/.ssh/config << 'EOF'
Host <project>-<env>
  HostName <EC2 IP>
  User root
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
EOF

mkdir -p ~/.ssh/sockets

# 5. 動作確認 (SSH 鍵は deploy が必要時に自動ロード)
nix run .#deploy
echo "Setup complete!"
```

> **注意**: SSH 秘密鍵はディスクに書き出さない。`nix run .#deploy` / `nix run .#deploy-ssh` は
> 必要時に operator key を自動ロードする。手動 SSH 接続だけ必要な場合は `nix run .#ssh-load`
> を使う。KMS Decrypt 権限がある限り、いつでもロード可能。

### 開発者を削除する

```bash
# 1. locals.tf から削除
cd infra/tfc-bootstrap
# locals.tf を編集: developers リストから名前を削除

# 2. git commit + push
git add locals.tf
git commit -m "Remove developer: old-developer"
git push

# 3. Bootstrap apply (IAM user が自動削除される)
sops exec-env ../../secrets/infra.yaml -- terraform apply

# KMS policy からも自動的に外れるため、
# 以後 sops decrypt は不可能になる。
# → 退職者が鍵をキャッシュしている可能性がある場合のみ、鍵ローテーションを実施する。
# ローテーション手順:
#   1. ssh-keygen -t ed25519 -f /tmp/operator -N "" -C "operator"
#   2. sops encrypt --input-type binary /tmp/operator > secrets/ssh/operator.yaml
#   3. NixOS の authorizedKeys を新しい公開鍵に更新
#   4. rm /tmp/operator /tmp/operator.pub
#   5. commit + deploy
```

### 自動で管理される権限

| 権限 | 管理方法 | 追加 | 削除 |
|------|----------|------|------|
| KMS (SOPS) | Terraform (developers.tf) | locals.tf に追加 → apply | locals.tf から削除 → apply |
| SSH (Operator) | SOPS (secrets/ssh/operator.yaml) | 共有鍵 — 追加作業なし | 退職者がキャッシュ済みの場合のみローテーション |
| SSH (Deploy) | SOPS (secrets/ssh/deploy.yaml) | 共有鍵 — 追加作業なし | 漏洩時のみローテーション |
| AWS (他リソース) | — | 付与しない（最小権限） | — |

---

## 13. デプロイ最適化（透過的オプション）

以下は deploy の正しさを変えない高速化だけを扱う。無効でも deploy pipeline 自体は成立する。

### デプロイと最適化の境界

- deploy の責務: build, activate, verify, rollback
- 最適化の責務: cache hit を増やす、不要な rebuild を減らす、転送を速くする
- Self-Deploy は deploy mode であり、最適化ではない
- `Cachix` と `nix-filter` は透過的な加速器であり、前提条件ではない

### デプロイパイプライン分析

```
nix run .#deploy
    │
    ├── 1. Dependency resolution   ~1-2s    (SSH 鍵 / Cachix token の自動解決)
    ├── 2. Nix evaluation          ~5s      (flake.nix → NixOS closure 計算)
    ├── 3. App derivation build    ~30-60s  (依存インストール + ビルド)
    ├── 4. Cachix publish          ~10-20s  (closure を Cachix に push)
    ├── 5. colmena apply           ~5-10s   (activation)
    └── 6. Verification            ~5-10s   (smoke test + revision verify)
                                   ─────────
                            合計: ~56-107s (typical)
                            Cache hit: ~15-25s (ビルド済みの場合)
```

Self-Deploy も同じステップを踏む。違いは build が EC2 上で走る点だけであり、cache miss 時はローカルビルド後に push-back される。

従来の SSH `nix-copy-closure` と比較して:
- **Cachix push/pull は並列転送**で SSH の単一ストリーム転送より高速
- **Cache hit 時は build が大きく短縮**される（他開発者や staging の push-back が効く）
- cache miss でも deploy は継続し、成功後に push-back で次回以降を高速化できる

### 追加最適化 1: `nix-filter` によるソースフィルタリング（効果: 大）

`nix-filter` で、ビルドに不要なファイル（doc, infra, secrets 等）をソースから除外する。deploy semantics は変えずに rebuild 範囲だけを狭める。

```nix
# flake.nix
inputs.nix-filter.url = "github:numtide/nix-filter";

# application derivation
src = nix-filter.lib {
  root = ../.;
  include = [
    "src"
    "package.json"
    "package-lock.yaml"  # or pnpm-lock.yaml
  ];
};
```

infra, doc, nixos ディレクトリの変更ではアプリの再ビルドが走らなくなる。

### 追加最適化 2: SSH 多重化 + 圧縮（効果: 中、フォールバック時）

SSH config で接続を再利用し、転送を圧縮する。Cachix 障害時の `deploy-ssh` フォールバックで有効。

```
Host <project>-<env>
  HostName <EC2 IP>
  User root
  # IdentityFile 不要 — ssh-agent が SOPS 経由でロードした鍵を保持
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
```

### 追加最適化 3: CI / ローカル pre-warm（効果: 中）

`git push` だけでも Self-Deploy は成立するが、CI やローカルで先に build して Cachix に publish すると staging / prod の cache hit 率が上がる。

### 最適化の優先順位

| 施策 | 作業量 | 効果 | 推奨時期 |
|------|--------|------|----------|
| Cachix Binary Cache | **デフォルト** | 大 | 初期セットアップ時 |
| `nix-filter` | 5分 | 大 | 即座に |
| SSH 多重化 | 5分 | 中 | 即座に |
| CI / ローカル pre-warm | 10-20分 | 中 | cache hit を上げたい時 |

---

## 14. トラブルシューティング

### SOPS 関連

**`Error decrypting key: AccessDeniedException`**

- IAM user に KMS の `Decrypt` 権限がない
- `aws sts get-caller-identity` で正しい IAM user か確認
- `infra/tfc-bootstrap/locals.tf` に自分のユーザー名があるか確認
- 既存の開発者に `terraform apply` を依頼

**`config file not found`**

- `.sops.yaml` がリポジトリルートにあるか確認
- カレントディレクトリまたは親ディレクトリに `.sops.yaml` が必要

**SOPS ファイルを誤って平文で commit した場合**

```bash
# 1. git history を書き換え (force push が必要)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch secrets/<file>.yaml' HEAD

# 2. シークレットをローテーション（漏洩した前提で対応）
# 3. 新しいシークレットで SOPS ファイルを再作成
```

### Colmena / NixOS 関連

**`colmena apply` が SSH 接続に失敗する**

`deploy` / `deploy-ssh` は operator key を自動ロードするため、
原因は `ssh-agent` 未起動か SOPS/KMS での復号失敗であることが多い。

```bash
# ssh-agent が起動しているか確認
ssh-add -l
# → "Could not open a connection to your authentication agent" なら:
eval "$(ssh-agent -s)"

# operator key を SOPS で復号できるか確認
sops exec-file secrets/ssh/operator.yaml \
  'ssh-keygen -y -f {} >/dev/null && echo "OK: operator key decryptable"'

# deploy は再実行で鍵を自動ロードする
nix run .#deploy

# 手動で切り分けたい場合のみ:
nix run .#ssh-load
ssh root@<EC2 IP>

# Security Group で port 22 が開いているか確認
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroups[].IpPermissions[?FromPort==`22`]'
```

**sops-nix が KMS 復号に失敗する**

```bash
# EC2 上で instance profile を確認
ssh <project>-<env> 'curl -s http://169.254.169.254/latest/meta-data/iam/info'

# IAM role に KMS Decrypt 権限があるか確認
aws iam get-role-policy --role-name <project>-ec2-sops --policy-name kms-decrypt-sops
```

**Let's Encrypt 証明書の取得に失敗する**

- DNS レコードが EC2 の EIP を指しているか確認
- Cloudflare の場合、proxy が無効 (gray cloud) であること（HTTP-01 challenge のため）
- Security Group で port 80 が開いていること
- `journalctl -u acme-<domain>.service` でログを確認

**EC2 が Cachix から closure を pull できない**

```bash
# EC2 上で Cachix substituter の設定を確認
ssh <project>-<env> 'nix show-config | grep substituters'
# → https://<project>.cachix.org が含まれていること

# EC2 上で Cachix からの fetch を手動テスト
ssh <project>-<env> 'nix store ping --store https://<project>.cachix.org'

# trusted-public-keys が正しいか確認
ssh <project>-<env> 'nix show-config | grep trusted-public-keys'

# フォールバック: Cachix 障害時はローカルから SSH 直接転送
nix run .#deploy-ssh
```

**EC2 で OOM が発生する**

```bash
# メモリ使用状況を確認
ssh <project>-<env> free -h

# nix-daemon のメモリ制限を確認
ssh <project>-<env> systemctl show nix-daemon | grep MemoryMax

# Swap が有効か確認
ssh <project>-<env> swapon --show
```

### Self-Deploy Webhook 関連

**Webhook が反応しない**

```bash
# EC2 上で webhook サービスの状態を確認
ssh <project>-<env> systemctl status deploy-webhook
ssh <project>-<env> journalctl -u deploy-webhook -f

# hooks.json が正しく生成されているか
ssh <project>-<env> cat /run/deploy-webhook/hooks.json
# → __WEBHOOK_SECRET__ が残っていたら sops-nix の起動順序問題

# GitHub 側の Webhook delivery を確認
# repo → Settings → Webhooks → Recent Deliveries
# 200 以外なら HMAC secret の不一致 or ref パターン不一致
```

**Deploy が並列実行されている**

```bash
# flock が効いていない場合、ロックファイルを確認
ssh <project>-<env> ls -la /run/<project>-deploy.lock

# transient unit の一覧
ssh <project>-<env> systemctl list-units '<project>-deploy-*'
```

**git pull が Permission denied (publickey)**

```bash
# deploy key が sops-nix で展開されているか
ssh <project>-<env> ls -la /run/secrets/github-deploy-key

# SSH 接続テスト
ssh <project>-<env> 'GIT_SSH_COMMAND="ssh -i /run/secrets/github-deploy-key" git ls-remote git@github.com:<org>/<repo>.git'

# GitHub の Deploy Key 設定を確認（read access が有効か）
```

### Terraform 関連

**State lock エラー（local state の場合）**

```bash
# .terraform.tfstate.lock.info を削除 (他の terraform が実行中でないことを確認)
rm .terraform.tfstate.lock.info
```

**`sops exec-env` で変数が注入されない**

```bash
# 環境変数のプレフィックスを確認
# Terraform は TF_VAR_<name> で変数を読む
# secrets/infra.yaml のキー名が variables.tf と一致しているか確認

# デバッグ: 環境変数を表示
sops exec-env secrets/infra.yaml -- env | grep TF_VAR_

# SOPS の YAML キー名に注意:
#   cloudflare_api_token → TF_VAR_cloudflare_api_token として注入される
```
