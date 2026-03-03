## 6. シークレット管理 (SOPS + AWS KMS)

### フロー

```
Developer                        EC2 Instance
    │                                 │
    │  sops --encrypt                 │
    │  (AWS CLI + KMS Encrypt)        │
    ▼                                 │
secrets/<project>-<env>.yaml          │
    │  (暗号化済み, git 管理)          │
    │                                 │
    │  colmena apply ────────────▶    │
    │  (SSH で転送)                    │  sops-nix activation
    │                                 │  (IAM instance profile → KMS Decrypt)
    │                                 ▼
    │                            /run/secrets/*
    │                                 │
    │                            EnvironmentFile (sops.templates)
    │                                 │
    │                            systemd services が参照
```

### .sops.yaml の設定

```yaml
# .sops.yaml (リポジトリルート)
creation_rules:
  # インフラシークレット
  - path_regex: secrets/infra\.yaml$
    kms: "arn:aws:kms:<region>:<account-id>:key/<key-id>"

  # CI/CD シークレット (Self-Deploy + Cachix)
  - path_regex: secrets/ci\.yaml$
    kms: "arn:aws:kms:<region>:<account-id>:key/<key-id>"

  # アプリケーションシークレット (環境別)
  - path_regex: secrets/<project>-.*\.yaml$
    kms: "arn:aws:kms:<region>:<account-id>:key/<key-id>"
```

### シークレットファイルの構造

```yaml
# secrets/infra.yaml (SOPS 暗号化、git commit)
# インフラ管理に必要なシークレット

# DNS プロバイダの API token
dns_api_token: "xxx..."
dns_zone_id: "xxx..."

# SSH key pair (deploy 用)
# 初回生成: ssh-keygen -t ed25519 -f ~/.ssh/<project>-deploy
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
ssh_public_key: "ssh-ed25519 AAAA... <project>-deploy"
```

```yaml
# secrets/<project>-prod.yaml (SOPS 暗号化、git commit)
# アプリケーションが必要とするシークレット

database_url: "mysql://user@localhost:3306/dbname"
jwt_secret: "<random>"
api_key: "<value>"
# ... アプリケーション固有のシークレット
```

### SOPS 基本操作

```bash
# 新規作成 (エディタが開く、保存時に自動暗号化)
sops secrets/<project>-prod.yaml

# 編集 (復号 → エディタ → 保存時に再暗号化)
sops secrets/<project>-prod.yaml

# 復号して標準出力
sops -d secrets/<project>-prod.yaml

# 特定の値を抽出
sops -d secrets/infra.yaml | yq '.ssh_private_key'

# 環境変数として注入して任意のコマンドを実行
sops exec-env secrets/infra.yaml -- terraform apply

# 暗号化状態の確認 (git diff で暗号化キーだけ表示される)
cat secrets/<project>-prod.yaml  # → 暗号化された YAML が表示される
```

### 設定の原則

| 種類 | 保存先 | 方式 |
|------|--------|------|
| シークレット | `secrets/*.yaml` | SOPS 暗号化、git commit |
| 非シークレット設定 | `locals.tf` | plaintext、git commit |
| ~~terraform.tfvars~~ | ~~使わない~~ | ~~drift の原因~~ |

`terraform.tfvars` を使わない理由: 各開発者のローカルに `.tfvars` ファイルがあると、内容の差異（drift）が生じやすく、「誰の `.tfvars` が正しいのか」問題が発生する。全ての設定を git 管理することで single source of truth を保証する。
