## 9. 初回ブートストラップ手順

鶏卵問題を段階的に解決する。KMS → SOPS → Bootstrap → Infra の順序で構築。

### Phase 0: 準備

> **SSH 鍵管理**: ロールベースの共有鍵を SOPS で管理する。個人ごと・デバイスごとの鍵は生成しない。
> 個人の識別は AWS IAM (KMS Decrypt 権限) で行う。

```bash
# 1. SSH key pair を生成 (ロールベース共有鍵)

# Operator key (開発者全員が共有する SSH アクセス用)
ssh-keygen -t ed25519 -f /tmp/operator -N "" -C "operator"
# → /tmp/operator.pub の内容を NixOS authorizedKeys および Terraform ssh_public_key に使用

# Deploy key (Self-Deploy の git pull 用)
ssh-keygen -t ed25519 -f /tmp/deploy -N "" -C "deploy"
# → /tmp/deploy.pub を GitHub Deploy Keys に登録 (read-only)

# 2. Cachix cache を作成
cachix create <project>
# → public key と auth token を控える

# 3. リポジトリの基本構造を作成
mkdir -p secrets infra/tfc-bootstrap infra/terraform nixos

# 4. locals.tf に初期開発者を設定
cat > infra/tfc-bootstrap/locals.tf << 'EOF'
locals {
  developers = [
    "initial-developer",
  ]
}
EOF

git add infra/tfc-bootstrap/
git commit -m "Add bootstrap terraform configuration"
```

### Phase 1: KMS Key のみ作成

SOPS が依存する KMS key を先に作成する。この段階では SOPS は使えないため、IAM/KMS 全権限を持つ AWS credentials を直接使う（この操作のみ。以後は Developer credentials で完結する）。

```bash
cd infra/tfc-bootstrap
terraform init

# KMS key のみを作成 (IAM users はまだ作らない — KMS policy が参照するため)
terraform apply \
  -target=aws_kms_key.sops \
  -target=aws_kms_alias.sops

# KMS ARN を取得
terraform output kms_key_arn
# → arn:aws:kms:ap-northeast-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Phase 2: SOPS を設定し、シークレットを暗号化

```bash
cd ../..  # リポジトリルートへ

# 1. .sops.yaml を作成 (Phase 1 で取得した KMS ARN を使用)
cat > .sops.yaml << 'EOF'
creation_rules:
  - path_regex: secrets/.*\.yaml$
    kms: "arn:aws:kms:<region>:<account-id>:key/<key-id>"
EOF

# 2. SSH 秘密鍵を SOPS で暗号化
mkdir -p secrets/ssh
sops encrypt --input-type binary /tmp/operator > secrets/ssh/operator.yaml
sops encrypt --input-type binary /tmp/deploy > secrets/ssh/deploy.yaml

# 3. infra secrets を作成
sops secrets/infra.yaml
# エディタが開くので以下を入力:
#   dns_api_token: "<your-cloudflare-token>"
#   dns_zone_id: "<your-zone-id>"
#   ssh_public_key: "ssh-ed25519 AAAA... operator"  ← /tmp/operator.pub の内容

# 4. アプリケーション secrets を作成
sops secrets/<project>-prod.yaml
# エディタが開くのでアプリ用シークレットを入力

# 5. 一時ファイルを削除
rm /tmp/operator /tmp/operator.pub /tmp/deploy /tmp/deploy.pub

# 6. git commit
git add .sops.yaml secrets/
git commit -m "Add encrypted secrets via SOPS"
```

### Phase 3: Bootstrap 完了（Developer IAM Users 作成）

```bash
cd infra/tfc-bootstrap

# SOPS 経由で terraform apply (全リソース)
sops exec-env ../../secrets/infra.yaml -- terraform apply

# 出力確認
terraform output developer_usernames
terraform output kms_key_arn
```

### Phase 4: メインインフラ構築

```bash
cd ../terraform
terraform init

# SOPS 経由で apply (Cloudflare token 等を環境変数として注入)
sops exec-env ../../secrets/infra.yaml -- terraform apply

# 生成された JSON を git commit
git add infra-<project>-<env>.json
git commit -m "Add terraform output for colmena"
```

### Phase 5: 初回デプロイ

```bash
cd ../..  # リポジトリルートへ

# SSH config を設定
cat >> ~/.ssh/config << 'EOF'
Host <project>-<env>
  HostName <EC2 IP>
  User root
  # IdentityFile 不要 — ssh-agent が SOPS 経由でロードした鍵を保持
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
EOF

mkdir -p ~/.ssh/sockets

# 初回デプロイ (SSH 鍵は自動でロードされる)
# build → cachix push → colmena apply
# Cachix auth token は deploy スクリプト内で SOPS から自動抽出される
# (CACHIX_AUTH_TOKEN 環境変数。グローバル設定ファイルは変更しない)
nix run .#deploy
```

---

## 10. チェックリスト

### 新プロジェクト開始時

- [ ] リポジトリ構造を作成（セクション 4 参照）
- [ ] Operator SSH key pair を生成 → `secrets/ssh/operator.yaml` に SOPS 暗号化
- [ ] Deploy SSH key pair を生成 → `secrets/ssh/deploy.yaml` に SOPS 暗号化
- [ ] Cachix cache を作成 (`cachix create <project>`)
- [ ] Bootstrap Terraform を作成 (`infra/tfc-bootstrap/`)
- [ ] Phase 1: KMS key を作成 (`terraform apply -target=aws_kms_key.sops`)
- [ ] `.sops.yaml` を作成（KMS ARN を設定）
- [ ] `secrets/infra.yaml` を暗号化して作成
- [ ] `secrets/ci.yaml` を暗号化して作成（webhook secret, cachix auth token）
- [ ] `secrets/<project>-<env>.yaml` を暗号化して作成
- [ ] Phase 3: Bootstrap apply（Developer IAM users 作成）
- [ ] メイン Terraform を作成・apply（VPC, EC2, DNS）
- [ ] Terraform output JSON を git commit
- [ ] NixOS 構成を作成 (`nixos/`, `flake.nix`)
- [ ] `common.nix` に Cachix substituter を設定
- [ ] NixOS authorizedKeys に operator 公開鍵を設定
- [ ] SSH config を設定（多重化 + 圧縮）
- [ ] `nix run .#deploy` で初回デプロイ（SSH 鍵は自動ロード）
- [ ] HTTPS アクセスを確認
- [ ] `.gitignore` に `*.tfstate*` を追加

### Self-Deploy Webhook セットアップ

- [ ] staging 用 EC2 を Terraform で作成（`infra/terraform/staging/`）
- [ ] `secrets/<project>-staging.yaml` を作成
- [ ] `deploy.nix` を作成（webhook + deploy script + repo init）
- [ ] `secrets.nix` に deploy key と webhook secret の宣言を追加
- [ ] flake.nix に staging/prod 両方の Colmena ターゲット + `deploy.enable` を定義
- [ ] nginx に `/.well-known/deploy` → `localhost:9000` プロキシを追加
- [ ] GitHub で Deploy Key を登録（`secrets/ssh/deploy.yaml` に対応する公開鍵, read-only）
- [ ] GitHub で Webhook を登録（push event, HMAC secret）
- [ ] main push → staging 自動デプロイ（Cachix pull）を検証
- [ ] tag push → production 自動デプロイ（Cachix pull）を検証
- [ ] deploy スクリプトにロールバック機能が含まれていること
- [ ] EC2 の systemPackages に `colmena` と `git` が含まれていること

### 日常運用

#### 方法 1: ローカルデプロイ（手動）

- [ ] コード変更 → `nix run .#deploy` (build → cachix push → colmena apply)
- [ ] フォールバック → `nix run .#deploy-ssh` (SSH 直接転送)

#### 方法 2: Self-Deploy（自動）

- [ ] コード変更 → `nix run .#deploy` で build + cachix push → `git push` → staging 自動デプロイ
- [ ] staging 確認 → `git tag v*` → `git push --tags` → production 自動デプロイ
- [ ] 緊急時 → `nix run .#deploy-ssh` で SSH 直接デプロイ

#### 共通

- [ ] Secret 変更 → `sops edit` → `nix run .#deploy` or commit + push → 自動デプロイ
- [ ] インフラ変更 → `terraform apply` → JSON を git commit → デプロイ

### 開発者の追加

- [ ] `locals.tf` に追加
- [ ] `git commit` + `push`
- [ ] `terraform apply`（Bootstrap）
- [ ] 新メンバーにセットアップ手順を共有

### セキュリティレビュー

- [ ] KMS key rotation が有効か (`enable_key_rotation = true`)
- [ ] EC2 IAM role が最小権限か（`Decrypt` + `DescribeKey` のみ）
- [ ] Developer IAM policy が ABAC (Project タグ) でスコープ制限されているか
- [ ] `secrets/ssh/operator.yaml` と `secrets/ssh/deploy.yaml` が存在し SOPS 暗号化されているか
- [ ] NixOS authorizedKeys の公開鍵が SOPS 管理の秘密鍵と対応しているか
- [ ] `.tfstate` ファイルが gitignore されているか
- [ ] Security Group で不要なポートが開いていないか
- [ ] `PermitRootLogin = "prohibit-password"` が設定されているか
- [ ] EC2 の IMDSv2 が強制されていること (`http_tokens = "required"`)
- [ ] Security Group に IPv6 ルール (`ipv6_cidr_blocks`) が設定されていること
- [ ] EBS バックアップ (AWS Backup) が設定されていること
