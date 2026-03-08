## 変数定義

このドキュメントで使用するプレースホルダー:

| プレースホルダー | 説明 | 例 |
|---|---|---|
| `<project-name>` | プロジェクトの正式名称（ハイフン区切り） | `my-webapp` |
| `<project>` | `<project-name>` の短縮形（同一値） | `my-webapp` |
| `<env>` | デプロイ環境 | `staging`, `prod` |
| `<region>` | AWS リージョン | `ap-northeast-1` |
| `<account-id>` | AWS アカウント ID | `123456789012` |
| `<key-id>` | KMS Key ID | `xxxxxxxx-xxxx-...` |
| `<subdomain>` | DNS サブドメイン | `app` |
| `<domain>` | 完全修飾ドメイン名 | `app.example.com` |
| `<cidr>` | VPC CIDR ブロック | `10.0.0.0/16` |
| `<az>` | Availability Zone | `ap-northeast-1a` |
| `<admin-email>` | ACME 用管理者メール | `admin@example.com` |

---

## 1. アーキテクチャ概要

```
Developer Mac (aarch64-darwin / x86_64-linux)
  │
  ├─ terraform apply     → AWS (EC2, VPC, KMS, IAM) + DNS Provider
  ├─ sops encrypt/edit   → secrets/<project>-<env>.yaml (KMS 暗号化, git 管理)
  ├─ nix build + cachix push → Cachix Binary Cache (pre-built closure)
  ├─ git push            → GitHub Webhook → EC2 self-deploy (通常運用)
  └─ colmena apply       → SSH 経由で直接デプロイ (フォールバック/緊急時)
                               │
                               ▼
                      EC2 (NixOS, Community AMI)
                        ├─ Cachix substituter ... pre-built closure を pull
                        ├─ Database          ... EBS に永続化
                        ├─ Application       ... ビルド済みバイナリ or スクリプト
                        ├─ nginx             ... TLS + webhook プロキシ
                        ├─ webhook binary    ... GitHub push → self-deploy
                        ├─ colmena           ... apply-local で自己適用
                        └─ sops-nix          ... KMS で secrets を runtime 復号
```

このアーキテクチャの核となる特性は以下の通り。

- **初回ブートストラップ以降は特権不要**: KMS key の作成（一度きり）のみ IAM/KMS 全権限を持つ AWS credentials が必要。以後は開発者の追加・削除もインフラ変更も、既存の開発者なら誰でも `terraform apply` で完結する。ABAC (Project タグ) でスコープを制限。
- **シークレットは全て git 管理**: SOPS + KMS で暗号化された状態でリポジトリに含まれるため、外部のパスワードマネージャーや手動の鍵配布が不要。
- **Cachix Binary Cache による転送**: ローカルでビルドした NixOS closure を Cachix に push し、EC2 は substituter 経由で pull する。SSH 経由の `nix-copy-closure` 転送が不要になり、デプロイが高速化される。
- **Self-Deploy Webhook**: EC2 が GitHub webhook を直接受信し `colmena apply-local` で自己デプロイ。Cachix から pre-built closure を pull するため、EC2 上でのビルド負荷はほぼゼロ。
- **デプロイに外部 credentials 不要**: EC2 の instance profile が KMS 復号を担当。外部 CI/CD サービスに SSH key や AWS credentials を保存する必要がない。
- **フォールバック**: Cachix 障害時は `colmena apply` による SSH 直接転送で即座にデプロイ可能。

---

## 2. 設計思想と判断根拠

### なぜこの構成か

| 決定事項 | 選択 | 根拠 |
|----------|------|------|
| OS | NixOS (Community AMI) | 宣言的構成。`nixos-rebuild switch` で冪等に全サービスを管理。再現性が高い。 |
| デプロイツール | Colmena | NixOS フリート管理に特化。flake native。SSH ベースで追加インフラ不要。 |
| シークレット管理 | SOPS + AWS KMS | git 管理可能な暗号化。KMS は IAM と統合されるためアクセス制御が容易。 |
| インフラ管理 | Terraform (local state) | 宣言的。小〜中規模では local state で十分。Terraform Cloud への移行も容易。 |
| TLS | Let's Encrypt (NixOS ACME) | 完全自動。証明書の手動管理が不要。NixOS module として標準サポート。 |
| DNS | Cloudflare (DNS only) | HTTP-01 challenge のために proxy を無効にする（gray cloud）。他の DNS プロバイダでも可。 |
| DB | EC2 上 (EBS 永続化) | 小〜中規模では RDS は過剰。EBS snapshot でバックアップ可能。 |
| ビルド転送 | Cachix Binary Cache | ローカルビルド → Cachix push → EC2 pull。SSH 転送不要。EC2 のビルド負荷ゼロ。 |
| ビルド | ローカル (Mac Linux Builder) | EC2 のメモリが限定的な場合に有効。buildOnTarget=true への切り替えも容易。 |
| CI/CD | Self-Deploy Webhook | EC2 が GitHub webhook を直接受信し `colmena apply-local` で自己デプロイ。外部 CI 不要。 |
| TF State | Local (.tfstate, gitignored) | 初期はシンプルに。チーム拡大時に S3 backend や TFC に移行。 |

### なぜ SOPS + KMS か（他の選択肢との比較）

| 方式 | 長所 | 短所 | 判定 |
|------|------|------|------|
| SOPS + KMS | git 管理可能、IAM 統合、鍵のローテーションが KMS 側で自動 | AWS 依存 | **採用** |
| Vault (HashiCorp) | 高機能、動的シークレット | 運用コスト大、追加インフラ必要 | 過剰 |
| Colmena keys | Colmena native | 鍵ファイルを手動配布、git 管理しづらい | 管理が煩雑 |
| .env ファイル手動管理 | シンプル | git 管理不可、共有が困難、drift | 非推奨 |
| AWS Secrets Manager | AWS native | ランタイム API 呼び出し必要、コスト | NixOS 統合が弱い |

---

## 3. 前提条件

### 必須ツール

```bash
# Nix (flakes 有効)
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install

# SOPS
nix profile install nixpkgs#sops
# or: brew install sops

# AWS CLI
nix profile install nixpkgs#awscli2
# or: brew install awscli

# Terraform
nix profile install nixpkgs#terraform
# or: brew install terraform

# Colmena
nix profile install nixpkgs#colmena

# Cachix (Binary Cache)
nix profile install nixpkgs#cachix

# yq (YAML 処理)
nix profile install nixpkgs#yq-go
```

### Mac で aarch64-linux をビルドする場合

NixOS Community AMI は aarch64 (ARM) を使用する場合、Mac 上でクロスビルドするために Linux Builder が必要。

```bash
# Nix Linux Builder (Determinate Systems)
# https://github.com/DeterminateSystems/nix-installer
# Determinate Nix installer で自動設定される

# 確認
nix build --system aarch64-linux nixpkgs#hello
```

x86_64 の場合は `buildOnTarget = true;` にするか、x86_64-linux のビルダーを使用する。

### AWS アカウント

- IAM/KMS 全権限を持つ AWS credentials（初回ブートストラップ時のみ使用。以後は不要）
- `~/.aws/credentials` に設定済み

### DNS

- Cloudflare（推奨）または他の DNS プロバイダ
- Terraform provider が利用可能であること

---

## 4. ディレクトリ構造

```
<project-name>/
├── .sops.yaml                           # SOPS 設定 (KMS ARN を指定)
├── secrets/
│   ├── infra.yaml                       # 暗号化: インフラ用シークレット
│   │                                    #   (DNS API token, SSL cert 等)
│   ├── ci.yaml                          # 暗号化: Self-Deploy + Cachix 用
│   │                                    #   (webhook HMAC secret, cachix auth token)
│   ├── ssh/
│   │   ├── operator.yaml                # 暗号化: 開発者 SSH 秘密鍵 (共有, ロールベース)
│   │   └── deploy.yaml                  # 暗号化: Self-Deploy 用 SSH 秘密鍵 (GitHub Deploy Key)
│   ├── <project>-staging.yaml           # 暗号化: staging 用 (DB URL, API keys)
│   └── <project>-prod.yaml              # 暗号化: production 用 (DB URL, API keys)
├── infra/
│   ├── tfc-bootstrap/                   # Phase 1: KMS + Developer IAM
│   │   ├── main.tf                      # AWS provider, local state
│   │   ├── variables.tf                 # 変数定義 (SOPS から注入)
│   │   ├── kms.tf                       # KMS key (SOPS 用)
│   │   ├── developers.tf                # Developer IAM users
│   │   ├── locals.tf                    # 開発者リスト (plaintext, git 管理)
│   │   └── outputs.tf                   # KMS ARN, IAM usernames
│   └── terraform/                       # Phase 2: AWS + DNS リソース
│       ├── main.tf                      # Providers, local state
│       ├── variables.tf                 # 変数定義
│       ├── network.tf                   # VPC, Subnet, SG, IGW
│       ├── compute.tf                   # EC2, EIP, instance profile
│       ├── iam.tf                       # EC2 用 IAM role (KMS decrypt)
│       ├── dns.tf                       # DNS レコード (Cloudflare 等)
│       ├── outputs.tf                   # IP, instance ID 等
│       └── infra-<project>-<env>.json   # 生成物: Colmena が読む
├── nixos/
│   ├── common.nix                       # SSH, firewall, users, substituter
│   ├── infrastructure.nix               # AMI, system base, swap, nix-daemon
│   ├── application.nix                  # DB, App, nginx, SOPS, ACME
│   ├── secrets.nix                      # sops-nix シークレット宣言
│   └── deploy.nix                       # Self-Deploy: webhook + deploy script + repo clone
├── tests/smoke/
│   └── smoke.sh                         # ヘルスチェック (retry付き)
└── flake.nix                            # Colmena hive, devShell, deploy app
```

### 各ファイルの責務

| パス | 管理方法 | 内容 |
|------|----------|------|
| `.sops.yaml` | plaintext, git | KMS ARN と暗号化ルールの定義 |
| `secrets/*.yaml` | SOPS 暗号化, git | 全てのシークレット |
| `infra/tfc-bootstrap/locals.tf` | plaintext, git | 開発者リスト（宣言的管理） |
| `infra/tfc-bootstrap/*.tf` | plaintext, git | KMS + IAM の Terraform 定義 |
| `infra/terraform/*.tf` | plaintext, git | AWS インフラの Terraform 定義 |
| `infra/terraform/*.json` | 生成物, git | Terraform output → Colmena 入力 |
| `nixos/*.nix` | plaintext, git | NixOS 構成 |
| `nixos/deploy.nix` | plaintext, git | Self-Deploy: webhook + deploy script |
| `nixos/secrets.nix` | plaintext, git | sops-nix シークレット宣言 |
| `tests/smoke/smoke.sh` | plaintext, git | ヘルスチェック |
| `flake.nix` | plaintext, git | Nix flake (Colmena hive 定義) |
| `*.tfstate` | **gitignored** | Terraform state (ローカル保存) |

---

## 5. アクセスモデルと IAM 設計

### 全体像

```
                     ┌──────────────────────────────────────────────────┐
                     │           AWS Account                            │
                     │                                                  │
  Bootstrap ────────▶│  KMS Key: alias/<project>-sops                   │
  Operator           │    ├─ Encrypt: Bootstrap Operator, Developers    │
  (初回のみ)         │    └─ Decrypt: Developers, EC2 Instance Profile  │
                     │                                                  │
  Terraform ────────▶│  IAM Role: <project>-ec2-sops                    │
  (Developer creds)  │    └─ KMS Decrypt only (instance profile)        │
                     │                                                  │
  Colmena ──────────▶│  EC2 Instance ◀── colmena apply (SSH)            │
  (SSH key only)     │    └─ sops-nix: instance profile → KMS           │
                     └──────────────────────────────────────────────────┘
```

### 2 種類の IAM エンティティ

**1. Developer IAM Users**（`tfc-bootstrap/developers.tf` で自動生成）

- IAM path: `/developers/<project>/<username>`
- 権限（ABAC: Project タグでスコープ制限）:
  - KMS: `Encrypt`, `Decrypt`, `DescribeKey`, `PutKeyPolicy`, `GetKeyPolicy`
  - IAM: Developer user 管理（`/developers/<project>/*` パスに限定）+ Role/InstanceProfile 管理（`<project>-*` に限定）
  - EC2: インスタンス、VPC、SG、EIP 等の管理（Project タグ一致のみ）
  - Backup: バックアップ管理（Project タグ一致のみ）
- Access key: Terraform では管理しない（既存メンバーが初回分を作成して渡す）
- 初回ブートストラップ後のすべての操作を自律的に実行可能

**2. EC2 Instance Profile IAM Role**（`terraform/iam.tf` で作成）

- Role 名: `<project>-ec2-sops`
- 権限: `kms:Decrypt` + `kms:DescribeKey` のみ（最小権限）
- 用途: `sops-nix` がサービス起動時に KMS 復号するために使用

### Credential Matrix

| 操作 | 必要な認証情報 | 頻度 |
|------|---------------|------|
| Bootstrap（初回 KMS key 作成のみ） | IAM/KMS 全権限を持つ AWS credentials | 一度きり |
| 開発者の追加・削除 | Developer IAM credentials | 時々 |
| インフラ変更 (`terraform apply`) | Developer IAM credentials | 稀 |
| Secret 編集 (`sops edit`) | Developer IAM credentials (KMS) | 時々 |
| ローカルビルド + Cachix push | Cachix auth token (SOPS から自動抽出) | 毎デプロイ |
| GitHub Webhook 登録 | GitHub token (SOPS → Terraform) | 初回 + 変更時 |
| Self-Deploy: staging (自動) | なし（webhook + Cachix pull） | 毎 main push |
| Self-Deploy: production (自動) | なし（webhook + Cachix pull） | 毎タグ push |
| フォールバックデプロイ (`colmena apply`) | SSH private key のみ (SOPS 経由) | 緊急時 |

> **SSH key 管理**: ロールベースの共有鍵を SOPS で管理する。個人ごと・デバイスごとの鍵は生成しない。
> - `secrets/ssh/operator.yaml` — 開発者全員が共有する SSH 秘密鍵 (人間の SSH アクセス用)
> - `secrets/ssh/deploy.yaml` — Self-Deploy / colmena 用の SSH 秘密鍵
> - 個人の識別は AWS IAM (KMS Decrypt 権限) で行う。SSH 鍵の名前では識別しない。

最も頻繁な操作であるデプロイ時に AWS credentials が不要という点が重要。ローカルでビルドした closure は Cachix に push され、EC2 は substituter 経由で pull する。暗号化された secrets ファイルはそのまま EC2 に転送され、EC2 の instance profile が KMS 復号を行う。
