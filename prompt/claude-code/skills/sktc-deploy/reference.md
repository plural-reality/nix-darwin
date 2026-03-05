## 15. トラブルシューティング

### SOPS 関連

**`Error decrypting key: AccessDeniedException`**

- IAM user に KMS の `Decrypt` 権限がない
- `aws sts get-caller-identity` で正しい IAM user か確認
- `infra/tfc-bootstrap/locals.tf` に自分のユーザー名があるか確認
- Bootstrap operator に `terraform apply` を依頼

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

```bash
# ssh-agent に operator key がロードされているか確認
ssh-add -l
# → "operator" のエントリが表示されること
# なければロード:
nix run .#ssh-load
# または: sops exec-file secrets/ssh/operator.yaml 'ssh-add {}'

# SSH 接続テスト
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

---

## 16. チェックリスト

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
- [ ] `nix run .#deploy` で初回デプロイ（build → cachix push → colmena apply）
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
- [ ] Developer IAM users が KMS 以外の権限を持っていないか
- [ ] `secrets/ssh/operator.yaml` と `secrets/ssh/deploy.yaml` が存在し SOPS 暗号化されているか
- [ ] NixOS authorizedKeys の公開鍵が SOPS 管理の秘密鍵と対応しているか
- [ ] `.tfstate` ファイルが gitignore されているか
- [ ] Security Group で不要なポートが開いていないか
- [ ] `PermitRootLogin = "prohibit-password"` が設定されているか
- [ ] EC2 の IMDSv2 が強制されていること (`http_tokens = "required"`)
- [ ] Security Group に IPv6 ルール (`ipv6_cidr_blocks`) が設定されていること
- [ ] EBS バックアップ (AWS Backup) が設定されていること
