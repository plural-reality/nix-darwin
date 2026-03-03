## 9. 初回ブートストラップ手順

鶏卵問題を段階的に解決する。KMS → SOPS → Bootstrap → Infra の順序で構築。

### Phase 0: 準備

> **注意**: SSH key ファイル名は `<project>-<role>-<person>-<computer>-<date>` 形式を推奨。
> ただし `secrets/infra.yaml` に格納するデプロイ共有鍵は `<project>-deploy` で統一する。

```bash
# 1. SSH key pair を生成
# 命名規則: <project>-<role>-<person>-<computer>-<date>
ssh-keygen -t ed25519 \
  -f ~/.ssh/<project>-deploy-$(whoami)-$(hostname -s)-$(date +%Y%m%d) \
  -C "<project>-deploy"

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

SOPS が依存する KMS key を先に作成する。この段階では SOPS は使えないため、AWS admin credentials を直接使う。

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

# 2. infra secrets を作成
sops secrets/infra.yaml
# エディタが開くので以下を入力:
#   dns_api_token: "<your-cloudflare-token>"
#   dns_zone_id: "<your-zone-id>"
#   ssh_private_key: |
#     <~/.ssh/<project>-deploy の内容をペースト>
#   ssh_public_key: "ssh-ed25519 AAAA... <project>-deploy"

# 3. アプリケーション secrets を作成
sops secrets/<project>-prod.yaml
# エディタが開くのでアプリ用シークレットを入力

# 4. git commit
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
  IdentityFile ~/.ssh/<project>-deploy-*
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
EOF

mkdir -p ~/.ssh/sockets

# 初回デプロイ (build → cachix push → colmena apply)
# Cachix auth token は deploy スクリプト内で SOPS から自動抽出される
# (CACHIX_AUTH_TOKEN 環境変数。グローバル設定ファイルは変更しない)
nix run .#deploy
```
