# SKTC Deployment Architecture

**SOPS + KMS + Terraform + Colmena による宣言的デプロイアーキテクチャ**

> このドキュメントは、任意の Web アプリケーションを AWS EC2 (NixOS) にデプロイするための汎用ガイドです。
> プロジェクト固有の設定はプレースホルダー（`<project-name>` 等）で表記しています。

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [設計思想と判断根拠](#2-設計思想と判断根拠)
3. [前提条件](#3-前提条件)
4. [ディレクトリ構造](#4-ディレクトリ構造)
5. [アクセスモデルと IAM 設計](#5-アクセスモデルと-iam-設計)
6. [シークレット管理 (SOPS + AWS KMS)](#6-シークレット管理-sops--aws-kms)
7. [インフラストラクチャ (Terraform)](#7-インフラストラクチャ-terraform)
8. [NixOS 構成](#8-nixos-構成)
9. [初回ブートストラップ手順](#9-初回ブートストラップ手順)
10. [日常運用](#10-日常運用)
11. [開発者オンボーディング](#11-開発者オンボーディング)
12. [デプロイ最適化](#12-デプロイ最適化)
13. [Self-Deploy Webhook パイプライン](#13-self-deploy-webhook-パイプライン)
14. [同一 AWS アカウントでの複数プロジェクト共存](#14-同一-aws-アカウントでの複数プロジェクト共存)
15. [トラブルシューティング](#15-トラブルシューティング)
16. [チェックリスト](#16-チェックリスト)

---

## 1. アーキテクチャ概要

```
Developer Mac (aarch64-darwin / x86_64-linux)
  │
  ├─ terraform apply     → AWS (EC2, VPC, KMS, IAM) + DNS Provider
  ├─ sops encrypt/edit   → secrets/<project>-<env>.yaml (KMS 暗号化, git 管理)
  ├─ colmena apply       → NixOS closure をビルド → EC2 に SSH push (初回/緊急時)
  └─ git push            → GitHub Webhook → EC2 self-deploy (通常運用)
                               │
                               ▼
                      EC2 (NixOS, Community AMI)
                        ├─ Database          ... EBS に永続化
                        ├─ Application       ... ビルド済みバイナリ or スクリプト
                        ├─ nginx             ... TLS + webhook プロキシ
                        ├─ webhook binary    ... GitHub push → self-deploy
                        ├─ colmena           ... apply-local で自己適用
                        └─ sops-nix          ... KMS で secrets を runtime 復号
```

このアーキテクチャの核となる特性は以下の通り。

- **イニシャルブートストラップ以外は IAM ベースで開発者を完全管理**: 初回の KMS キー作成と `.sops.yaml` 設定のみ admin 権限が必要。以後の開発者の追加・削除は `locals.tf` を git commit して `terraform apply` するだけで完結する。
- **シークレットは全て git 管理**: SOPS + KMS で暗号化された状態でリポジトリに含まれるため、外部のパスワードマネージャーや手動の鍵配布が不要。
- **Self-Deploy Webhook**: EC2 が GitHub webhook を直接受信し `colmena apply-local` で自己デプロイ。main push → staging、v* tag → production。CI は検証（smoke test + auto-release）のみ。
- **デプロイに外部 credentials 不要**: EC2 の instance profile が KMS 復号を担当。GitHub Actions にも SSH key や AWS credentials を保存する必要がない。

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
| ビルド | ローカル (Mac Linux Builder) | EC2 のメモリが限定的な場合に有効。buildOnTarget=true への切り替えも容易。 |
| CI/CD | Self-Deploy Webhook | EC2 が GitHub webhook を直接受信し `colmena apply-local` で自己デプロイ。CI は検証のみ。 |
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

- IAM admin 相当の credentials（ブートストラップ時のみ使用）
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
│   │                                    #   (DNS API token, SSH key, SSL cert 等)
│   ├── ci.yaml                          # 暗号化: Self-Deploy 用
│   │                                    #   (GitHub deploy key, webhook HMAC secret)
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
├── .github/workflows/
│   └── deploy.yml                       # Post-deploy 検証: smoke test + auto-release
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
| `.github/workflows/deploy.yml` | plaintext, git | Post-deploy 検証（デプロイしない） |
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
  (admin creds)      │    └─ Decrypt: Developers, EC2 Instance Profile  │
                     │                                                  │
  Terraform ────────▶│  IAM Role: <project>-ec2-sops                    │
  (admin/dev creds)  │    └─ KMS Decrypt only (instance profile)        │
                     │                                                  │
  Colmena ──────────▶│  EC2 Instance ◀── colmena apply (SSH)            │
  (SSH key only)     │    └─ sops-nix: instance profile → KMS           │
                     └──────────────────────────────────────────────────┘
```

### 2 種類の IAM エンティティ

**1. Developer IAM Users**（`tfc-bootstrap/developers.tf` で自動生成）

- IAM path: `/developers/<project>/<username>`
- 権限: KMS の `Encrypt`, `Decrypt`, `DescribeKey` のみ（SOPS 操作用）
- Access key: Terraform では管理しない（開発者が自分で作成）
- `terraform apply` 権限: デフォルトでは付与しない（必要に応じて個別追加）

**2. EC2 Instance Profile IAM Role**（`terraform/iam.tf` で作成）

- Role 名: `<project>-ec2-sops`
- 権限: `kms:Decrypt` + `kms:DescribeKey` のみ（最小権限）
- 用途: `sops-nix` がサービス起動時に KMS 復号するために使用

### Credential Matrix

| 操作 | 必要な認証情報 | 頻度 |
|------|---------------|------|
| Bootstrap（初回/変更） | AWS admin credentials | 稀 |
| インフラ変更 (`terraform apply`) | AWS admin/developer credentials | 時々 |
| Secret 編集 (`sops edit`) | AWS credentials with KMS access | 時々 |
| アプリデプロイ (`colmena apply`) | **SSH private key のみ** | 頻繁 |

最も頻繁な操作であるデプロイ時に AWS credentials が不要という点が重要。暗号化された secrets ファイルはそのまま EC2 に転送され、EC2 の instance profile が KMS 復号を行う。

---

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

  # アプリケーションシークレット (環境別に分割可能)
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

---

## 7. インフラストラクチャ (Terraform)

### 2 層構成

Terraform は **bootstrap 層** と **メイン層** の 2 つに分離する。これは鶏卵問題を解決するため。

```
infra/tfc-bootstrap/     KMS key + Developer IAM
        ↓ (KMS ARN を出力)
.sops.yaml               KMS ARN を設定
        ↓ (SOPS が使用可能に)
secrets/*.yaml            シークレットを暗号化
        ↓ (SOPS 経由で注入)
infra/terraform/          VPC, EC2, EIP, DNS, IAM Role
```

### Bootstrap 層 (`infra/tfc-bootstrap/`)

#### `main.tf`

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state (bootstrap は頻繁に変更しないため)
  # gitignore に *.tfstate を追加すること
}

provider "aws" {
  region = "<region>"  # e.g., "ap-northeast-1"
  default_tags {
    tags = {
      Project   = "<project-name>"
      ManagedBy = "terraform"
      Layer     = "bootstrap"
    }
  }
}
```

#### `locals.tf`（開発者リスト — これが唯一の管理ポイント）

```hcl
locals {
  # ここに開発者を追加・削除するだけで IAM + KMS policy が自動更新される
  developers = [
    "taro-yamada",
    "hanako-sato",
  ]
}
```

#### `kms.tf`

```hcl
resource "aws_kms_key" "sops" {
  description             = "SOPS encryption key for <project-name>"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # KMS Key Policy:
  # - アカウント root: 全権限 (管理用)
  # - Developer IAM users: Encrypt + Decrypt (SOPS 操作用)
  # - EC2 IAM role: Decrypt のみ (runtime 復号用)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::<account-id>:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowDeveloperAccess"
        Effect = "Allow"
        Principal = {
          AWS = [for user in aws_iam_user.developer : user.arn]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource = "*"
      },
    ]
  })

  tags = {
    Name = "<project-name>-sops"
  }
}

resource "aws_kms_alias" "sops" {
  name          = "alias/<project-name>-sops"
  target_key_id = aws_kms_key.sops.key_id
}

output "kms_key_arn" {
  value       = aws_kms_key.sops.arn
  description = "KMS key ARN for .sops.yaml configuration"
}
```

#### `developers.tf`

```hcl
resource "aws_iam_user" "developer" {
  for_each = toset(local.developers)
  name     = each.value
  path     = "/developers/<project-name>/"

  tags = {
    Project = "<project-name>"
    Role    = "developer"
  }
}

# 注意: Access Key は Terraform で管理しない
# 開発者が自分で aws iam create-access-key を実行する
# これにより、secret access key が Terraform state に保存されない

output "developer_usernames" {
  value       = [for user in aws_iam_user.developer : user.name]
  description = "Created IAM usernames"
}
```

### メイン層 (`infra/terraform/`)

#### `main.tf`

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "<region>"
  default_tags {
    tags = {
      Project   = "<project-name>"
      ManagedBy = "terraform"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token  # SOPS exec-env で注入
}
```

#### `variables.tf`

```hcl
# SOPS exec-env 経由で環境変数から注入される
# 環境変数名: TF_VAR_<variable_name>

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "ssh_public_key" {
  type = string
}
```

#### `network.tf`

```hcl
# === VPC ===
resource "aws_vpc" "main" {
  cidr_block                       = "<cidr>"  # e.g., "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true       # IPv6 dual-stack
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = { Name = "<project-name>-vpc" }
}

# === Subnet (Public) ===
resource "aws_subnet" "public" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = "<subnet-cidr>"  # e.g., "10.0.1.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 1)
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  availability_zone               = "<az>"  # e.g., "ap-northeast-1a"

  tags = { Name = "<project-name>-public" }
}

# === Internet Gateway ===
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "<project-name>-igw" }
}

# === Route Table ===
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "<project-name>-public-rt" }
}

resource "aws_route" "ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "ipv6" {
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# === Security Group ===
resource "aws_security_group" "app" {
  name_prefix = "<project-name>-"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (Let's Encrypt ACME challenge + redirect)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "<project-name>-sg" }
}
```

#### `compute.tf`

```hcl
# === NixOS Community AMI ===
data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["427812963091"]  # NixOS Community AMIs

  filter {
    name   = "name"
    values = ["nixos/25.05*"]  # NixOS バージョン
  }

  filter {
    name   = "architecture"
    values = ["arm64"]  # aarch64 (Graviton) — x86_64 なら "x86_64"
  }
}

# === SSH Key Pair ===
resource "aws_key_pair" "deploy" {
  key_name   = "<project-name>-deploy"
  public_key = var.ssh_public_key
}

# === EC2 Instance ===
resource "aws_instance" "app" {
  ami                    = data.aws_ami.nixos.id
  instance_type          = "t4g.small"  # 2 vCPU, 2GB RAM (ARM)
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deploy.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_sops.name

  root_block_device {
    volume_size = 30    # GB
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "<project-name>-<env>"
    Project = "<project-name>"
  }

  lifecycle {
    ignore_changes = [ami]  # NixOS が自己管理するため AMI 変更は無視
  }
}

# === Elastic IP ===
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "<project-name>-<env>" }
}
```

#### `iam.tf`（EC2 用 Instance Profile）

```hcl
# === EC2 が SOPS を復号するための IAM Role ===

data "aws_kms_key" "sops" {
  key_id = "alias/<project-name>-sops"
}

resource "aws_iam_role" "ec2_sops" {
  name = "<project-name>-ec2-sops"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = { Project = "<project-name>" }
}

resource "aws_iam_role_policy" "kms_decrypt" {
  name = "kms-decrypt-sops"
  role = aws_iam_role.ec2_sops.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
      ]
      Resource = data.aws_kms_key.sops.arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_sops" {
  name = "<project-name>-ec2-sops"
  role = aws_iam_role.ec2_sops.name
}
```

#### `dns.tf`（Cloudflare の例）

```hcl
resource "cloudflare_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = "<subdomain>"       # e.g., "app" → app.example.com
  content = aws_eip.app.public_ip
  type    = "A"
  proxied = false               # HTTP-01 challenge のため proxy OFF
  ttl     = 300
}
```

#### `outputs.tf`

```hcl
output "instance_ip" {
  value = aws_eip.app.public_ip
}

output "instance_id" {
  value = aws_instance.app.id
}

# Colmena 用 JSON 出力
resource "local_file" "infra_json" {
  filename = "${path.module}/infra-<project>-<env>.json"
  content = jsonencode({
    host         = aws_eip.app.public_ip
    instance_id  = aws_instance.app.id
    hostname     = "<subdomain>.example.com"
    architecture = "aarch64"  # or "x86_64"
  })
}
```

---

## 8. NixOS 構成

### `flake.nix`（Colmena Hive 定義）

```nix
{
  description = "<project-name> deployment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";  # stable
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, colmena, ... }:
    let
      # Terraform が生成した JSON を読む
      infraConfig = builtins.fromJSON (
        builtins.readFile ./infra/terraform/infra-<project>-<env>.json
      );
    in {
      colmenaHive = colmena.lib.makeHive {
        meta = {
          nixpkgs = import nixpkgs {
            system = "aarch64-linux";  # EC2 のアーキテクチャ
          };
        };

        # --- デプロイターゲット ---
        "<project>-<env>" = { name, nodes, pkgs, ... }: {
          deployment = {
            targetHost = infraConfig.host;
            targetUser = "root";
            buildOnTarget = false;  # ローカルビルド (Mac Linux Builder)
            # buildOnTarget = true;  # EC2 上でビルド (RAM に余裕がある場合)
          };

          imports = [
            sops-nix.nixosModules.sops
            ./nixos/common.nix
            ./nixos/infrastructure.nix
            ./nixos/application.nix
          ];

          # NixOS の hostname
          networking.hostName = "<project>-<env>";
        };
      };

      # 便利: nix run .#deploy
      apps.aarch64-darwin.deploy = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy" ''
          set -euo pipefail
          echo "Deploying <project-name>..."
          time ${colmena.packages.aarch64-darwin.colmena}/bin/colmena apply \
            --impure --on <project>-<env> "$@"
        ''}";
      };
    };
}
```

### `nixos/common.nix`（共通設定）

```nix
{ config, pkgs, lib, ... }:

{
  # === SSH ===
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # === Firewall ===
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # === Nix Settings ===
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;

      # EC2 が cache.nixos.org から直接パッケージを取得
      # → colmena の SSH 転送を削減
      substituters = [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # 定期的にストアを GC
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # === nix-daemon メモリ制限 ===
  # EC2 の RAM が限定的な場合に OOM を防止
  systemd.services.nix-daemon.serviceConfig = {
    MemoryMax = "1536M";
  };

  # === タイムゾーン ===
  time.timeZone = "UTC";

  # === 基本パッケージ ===
  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    jq
  ];
}
```

### `nixos/infrastructure.nix`（EC2 + システムベース）

```nix
{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  # === NixOS Community AMI 互換設定 ===
  ec2.hvm = true;

  # === Swap (安全ネット) ===
  swapDevices = [{
    device = "/swapfile";
    size = 1024;  # MB
  }];

  # === EBS Root Volume ===
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # === System ===
  system.stateVersion = "25.05";
}
```

### `nixos/application.nix`（アプリケーション定義）

```nix
{ config, pkgs, lib, ... }:

let
  # --- プロジェクト固有の設定 ---
  appName = "<project-name>";
  appPort = 3000;  # アプリケーションのリッスンポート
  domain = "<subdomain>.example.com";
  dbName = "<project_db>";
  dbUser = "<project_user>";

  # --- アプリケーションパッケージ ---
  # ここにビルド定義を書く (言語・フレームワークに応じて変更)
  appPackage = pkgs.buildNpmPackage {
    pname = appName;
    version = "0.1.0";

    # ソースフィルタリング (最適化: 関係ないファイルの変更で再ビルドしない)
    src = let
      fs = pkgs.lib.fileset;
    in fs.toSource {
      root = ./.;
      fileset = fs.unions [
        # アプリに必要なファイルのみ列挙
        # ./src
        # ./package.json
        # ./package-lock.json
        # ...
      ];
    };

    # npmDepsHash = "sha256-...";
    # buildPhase = "npm run build";
    # installPhase = "...";
  };

in {

  # ===================================================
  #  SOPS (sops-nix)
  # ===================================================
  sops = {
    defaultSopsFile = ../secrets/${appName}-prod.yaml;
    age = {};  # age は使わない (KMS のみ)

    # KMS 復号: EC2 instance profile を使用
    # (追加設定不要 — sops-nix が自動で AWS metadata を使う)

    # 個別のシークレット
    secrets = {
      database_url = {};
      jwt_secret = {};
      api_key = {};
      # ... 必要なシークレットを列挙
    };

    # テンプレート: 複数のシークレットを 1 つの EnvironmentFile に結合
    templates."${appName}-env".content = ''
      DATABASE_URL=${config.sops.placeholder.database_url}
      JWT_SECRET=${config.sops.placeholder.jwt_secret}
      API_KEY=${config.sops.placeholder.api_key}
    '';
  };

  # ===================================================
  #  Database (MariaDB の例 — PostgreSQL 等に変更可)
  # ===================================================
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
      innodb_buffer_pool_size = "256M";  # RAM に応じて調整
    };
    ensureDatabases = [ dbName ];
    ensureUsers = [{
      name = dbUser;
      ensurePermissions = {
        "${dbName}.*" = "ALL PRIVILEGES";
      };
    }];
  };

  # ===================================================
  #  Application Service
  # ===================================================
  systemd.services."${appName}" = {
    description = "${appName} application server";
    after = [ "network.target" "mysql.service" ];
    requires = [ "mysql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      EnvironmentFile = config.sops.templates."${appName}-env".path;
      ExecStart = "${appPackage}/bin/${appName}";
      Restart = "on-failure";
      RestartSec = 5;

      # セキュリティ強化
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # ===================================================
  #  nginx + Let's Encrypt
  # ===================================================
  security.acme = {
    acceptTerms = true;
    defaults.email = "<admin-email@example.com>";
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts."${domain}" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString appPort}";
        proxyWebsockets = true;  # WebSocket が必要な場合
      };
    };
  };
}
```

### メモリバジェット例（2GB RAM）

| コンポーネント | 割り当て |
|----------------|----------|
| Database (innodb_buffer_pool) | 256 MB |
| Application | ~200 MB |
| nginx | ~10 MB |
| OS + nix-daemon | ~500 MB |
| nix-daemon MemoryMax | 1536 MB |
| Swap | 1 GB (safety net) |

---

## 9. 初回ブートストラップ手順

鶏卵問題を段階的に解決する。KMS → SOPS → Bootstrap → Infra の順序で構築。

### Phase 0: 準備

```bash
# 1. SSH key pair を生成
ssh-keygen -t ed25519 -f ~/.ssh/<project>-deploy -C "<project>-deploy"

# 2. リポジトリの基本構造を作成
mkdir -p secrets infra/tfc-bootstrap infra/terraform nixos

# 3. locals.tf に初期開発者を設定
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
  IdentityFile ~/.ssh/<project>-deploy
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
EOF

mkdir -p ~/.ssh/sockets

# 初回デプロイ
colmena apply --impure --on <project>-<env>
```

---

## 10. 日常運用

ブートストラップ完了後の日常操作は全てローカルから実行する。

```
┌──────────────────────────────────────────────────────────────┐
│  日常の開発サイクル                                            │
│                                                              │
│  コード変更のみ:                                              │
│    git commit → colmena apply --impure    (SSH key のみ)     │
│                                                              │
│  Secret 変更:                                                 │
│    sops edit → git commit → colmena apply (IAM KMS + SSH)    │
│                                                              │
│  インフラ変更:                                                │
│    *.tf 編集 → sops exec-env ... -- terraform apply          │
│    → JSON を git commit → colmena apply                      │
│                                                              │
│  Bootstrap 変更 (稀):                                         │
│    locals.tf 編集 → sops exec-env ... -- terraform apply     │
│    (新しい IAM user/policy 追加、KMS policy 変更)             │
└──────────────────────────────────────────────────────────────┘
```

### コマンドリファレンス

```bash
# === アプリケーションデプロイ ===
colmena apply --impure --on <project>-<env>
# or: nix run .#deploy

# === Secret 編集 ===
sops secrets/<project>-prod.yaml
# → 保存後に colmena apply で反映

# === インフラ変更 ===
cd infra/terraform
sops exec-env ../../secrets/infra.yaml -- terraform plan   # 確認
sops exec-env ../../secrets/infra.yaml -- terraform apply  # 適用

# === Bootstrap 変更 (Developer 追加等) ===
cd infra/tfc-bootstrap
sops exec-env ../../secrets/infra.yaml -- terraform apply

# === サーバー接続 ===
ssh <project>-<env>

# === ログ確認 ===
ssh <project>-<env> journalctl -u <project> -f
ssh <project>-<env> journalctl -u nginx -f
ssh <project>-<env> journalctl -u mysql -f

# === サービス状態確認 ===
ssh <project>-<env> systemctl status <project>
```

---

## 11. 開発者オンボーディング

### 新しい開発者を追加する（Bootstrap Operator が実行）

全て宣言的。git commit のみで完結する。

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
sops exec-env ../../secrets/infra.yaml -- terraform apply

# 4. 新メンバーに通知する内容:
#   - IAM username
#   - リポジトリ URL
#   - 以下のセットアップ手順
```

### 新メンバーのセットアップ手順

```bash
# 1. リポジトリを clone
git clone <repo-url>
cd <project>

# 2. AWS access key を作成 (自分の IAM user で)
#    AWS Console に admin にログインしてもらい、IAM User の Access Key を作成
#    または:
aws iam create-access-key --user-name <your-username>
# → AccessKeyId と SecretAccessKey を取得

# 3. AWS CLI を設定
aws configure
# AWS Access Key ID: <上で取得した値>
# AWS Secret Access Key: <上で取得した値>
# Default region: <region>

# 4. KMS アクセスを確認
aws sts get-caller-identity
sops -d secrets/<project>-prod.yaml > /dev/null && echo "OK: KMS access confirmed"

# 5. SSH private key を取得 (SOPS から復号)
sops -d secrets/infra.yaml | yq '.ssh_private_key' > ~/.ssh/<project>-deploy
chmod 600 ~/.ssh/<project>-deploy

# 6. SSH config を設定
cat >> ~/.ssh/config << 'EOF'
Host <project>-<env>
  HostName <EC2 IP>
  User root
  IdentityFile ~/.ssh/<project>-deploy
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
EOF

mkdir -p ~/.ssh/sockets

# 7. 動作確認
colmena apply --impure --on <project>-<env>
echo "Setup complete!"
```

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
# SSH key のローテーションは別途検討。
```

### 自動で管理される権限

| 権限 | 管理方法 | 追加 | 削除 |
|------|----------|------|------|
| KMS (SOPS) | Terraform (developers.tf) | locals.tf に追加 → apply | locals.tf から削除 → apply |
| SSH (Deploy) | SOPS (secrets/infra.yaml) | 共有鍵 — 追加作業なし | 鍵ローテーションで対応 |
| AWS (他リソース) | — | 付与しない（最小権限） | — |

---

## 12. デプロイ最適化

全て透過的な最適化。既存の `colmena apply` コマンドはそのまま動く。

### ボトルネック分析

```
colmena apply --impure --on <project>-<env>
    │
    ├── 1. Nix evaluation          ~5s      (flake.nix → NixOS closure 計算)
    ├── 2. App derivation build    ~30-60s  (依存インストール + ビルド)
    ├── 3. NixOS closure build     ~10-30s  (system closure をリンク)
    ├── 4. nix-copy-closure (SSH)  ~20-60s  (store paths を EC2 に転送)
    ├── 5. Activation              ~5-10s   (switch-to-configuration)
    └── 6. Service restart         ~3-5s
                                   ─────────
                            合計: ~70-170s (typical)
```

### 最適化 1: ソースフィルタリング（効果: 大）

`lib.fileset` で、ビルドに不要なファイル（doc, infra, secrets 等）をソースから除外する。

```nix
# flake.nix のアプリケーション derivation 内
src = let
  fs = pkgs.lib.fileset;
in fs.toSource {
  root = ./.;
  fileset = fs.unions [
    ./src
    ./package.json
    ./package-lock.yaml  # or pnpm-lock.yaml
    # ビルドに必要なファイルのみ列挙
  ];
};
```

infra, doc, nixos ディレクトリの変更ではアプリの再ビルドが走らなくなる。

### 最適化 2: SSH 多重化 + 圧縮（効果: 中）

SSH config で接続を再利用し、転送を圧縮する。

```
Host <project>-<env>
  HostName <EC2 IP>
  User root
  IdentityFile ~/.ssh/<project>-deploy
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  Compression yes
```

### 最適化 3: EC2 側 substituter（効果: 大）

EC2 が `cache.nixos.org` から直接パッケージを取得するよう設定する（`common.nix` に記載済み）。これにより、Node.js, MariaDB, nginx 等のシステムパッケージを Mac から SSH 転送する必要がなくなり、`nix-copy-closure` はアプリケーション固有の derivation のみを転送する。

### 最適化 4: Binary Cache（効果: 大 — 複数開発者向け）

Cachix（または S3 + nix-serve）で Nix binary cache をチーム共有する。

```bash
# Cachix セットアップ (1回)
cachix create <project>
cachix use <project>

# デプロイ後に cache に push
colmena apply --impure --on <project>-<env> && \
  cachix push <project> $(nix path-info --derivation .#colmenaHive.<project>-<env>)
```

```nix
# nixos/common.nix に追加
nix.settings.substituters = [
  "https://cache.nixos.org"
  "https://<project>.cachix.org"
];
nix.settings.trusted-public-keys = [
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  "<project>.cachix.org-1:XXXXX..."
];
```

### 最適化後の期待値

```
最適化前:  ~70-170s
最適化後:  ~30-40s  (コード変更のみ)
Cache hit: ~15-20s  (他開発者がビルド済み)
```

### 最適化の優先順位

| 施策 | 作業量 | 効果 | 推奨時期 |
|------|--------|------|----------|
| ソースフィルタリング | 5分 | 大 | 即座に |
| SSH 多重化 | 5分 | 中 | 即座に |
| EC2 substituter | 5分 | 大 | 即座に |
| Binary Cache (Cachix) | 30分 | 大 | チーム拡大時 |
| Self-Deploy Webhook | 2-3時間 | 大 (自動化) | staging/prod 分離時（セクション 13） |
| deploy ラッパー (`nix run .#deploy`) | 10分 | 小 (DX) | 任意 |

---

## 13. Self-Deploy Webhook パイプライン

### 設計思想

GitHub Actions は**デプロイしない**。EC2 が GitHub webhook を直接受信し、自分自身をデプロイする（Self-Deploy）。

CI の中間ノードを排除することで:
- SSH private key を GitHub Secrets に保存する必要がない
- CI runner のアーキテクチャ問題（x86_64 vs aarch64）が発生しない
- デプロイレイテンシが低い（webhook → 即実行）

```
Developer
  │
  ├─ push to main ──────┐
  │  or git tag v*       │
  │                      ▼
  │              GitHub Webhook (push event)
  │                      │
  │                      ▼
  │              EC2 :9000 (webhook binary)
  │                ├─ HMAC-SHA256 署名検証
  │                ├─ ref パターンマッチ
  │                └─ trigger-deploy (systemd-run, non-blocking)
  │                      │
  │                      ▼
  │              deploy script (flock 排他)
  │                ├─ git fetch + checkout/pull
  │                ├─ colmena apply-local --node <name>
  │                └─ smoke test (localhost)
  │                      │
  │              GitHub Actions (検証のみ)
  │                ├─ smoke test (外部から)
  │                └─ auto-release tag 生成 (staging → prod)
```

### 環境モデル

| Git Event | Environment | refPattern | EC2 の動作 |
|---|---|---|---|
| `push to main` | Staging | `^refs/heads/main$` | git pull → `colmena apply-local` |
| `tag v*` | Production | `^refs/tags/v` | git checkout tag → `colmena apply-local` |

staging は main の HEAD を常に追従。production はタグでのみ更新。

### 自動リリースフロー

```
main push
  → EC2 staging: webhook → self-deploy
  → GitHub Actions: smoke test staging
  → 成功 → auto-release tag 生成 (v20260303.123456)
  → tag push イベント発火
  → EC2 prod: webhook → self-deploy
  → GitHub Actions: smoke test production
```

main push 一発で staging → 自動テスト → production まで流れる。

### NixOS モジュール: `deploy.nix`

Self-Deploy の核。プロジェクト名を置換すれば横展開可能。

#### Option 定義

```nix
options.<project>.deploy = {
  enable     = lib.mkEnableOption "self-deploy webhook";
  nodeName   = lib.mkOption { type = lib.types.str; };   # colmena apply-local --node <name>
  refPattern = lib.mkOption { type = lib.types.str; };   # webhook の ref フィルタ regex
  repoUrl    = lib.mkOption { type = lib.types.str; };   # git clone SSH URL
};
```

#### 3 つの systemd サービス

```nix
# 1. 初回 git clone (idempotent oneshot)
systemd.services.deploy-repo-init = {
  after = [ "network-online.target" "sops-nix.service" ];
  requires = [ "sops-nix.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "clone-repo" ''
      set -euo pipefail
      [ -d "${repoDir}/.git" ] && exit 0
      mkdir -p "$(dirname "${repoDir}")"
      export GIT_SSH_COMMAND="${gitSshCommand}"
      git clone "${cfg.repoUrl}" "${repoDir}"
    '';
  };
};

# 2. Webhook receiver (localhost:9000)
systemd.services.deploy-webhook = {
  after = [ "deploy-repo-init.service" "sops-nix.service" ];
  requires = [ "deploy-repo-init.service" "sops-nix.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    # HMAC secret を /nix/store ではなく /run に展開
    ExecStartPre = pkgs.writeShellScript "generate-hooks" ''
      SECRET=$(cat /run/secrets/webhook-secret)
      sed "s|__WEBHOOK_SECRET__|$SECRET|g" ${hooksTemplate} > /run/deploy-webhook/hooks.json
    '';
    ExecStart = "${pkgs.webhook}/bin/webhook -hooks /run/deploy-webhook/hooks.json -port 9000 -verbose";
    RuntimeDirectory = "deploy-webhook";
    Restart = "always";
  };
};
```

#### Deploy スクリプト

```bash
# flock で排他制御 — 同時デプロイを防止
exec 200>/run/<project>-deploy.lock
flock -n 200 || { echo "Deploy already running, skipping"; exit 0; }

REF="$1"
export GIT_SSH_COMMAND="ssh -i /run/secrets/github-deploy-key"
cd /var/lib/<project>-deploy/repo

git fetch origin

case "$REF" in
  refs/tags/*)  TAG="${REF#refs/tags/}";    git checkout "$TAG" ;;
  refs/heads/*) BRANCH="${REF#refs/heads/}"; git checkout "$BRANCH"; git pull origin "$BRANCH" --ff-only ;;
esac

colmena apply-local --node <node-name> --verbose

# ローカル smoke test
curl -sf --max-time 10 http://localhost:<port>/api/health \
  && echo "Smoke test passed" \
  || echo "WARN: Smoke test failed (deploy itself succeeded)"
```

#### Webhook hooks.json テンプレート

```json
[{
  "id": "deploy",
  "execute-command": "/nix/store/.../trigger-deploy",
  "pass-arguments-to-command": [
    { "source": "payload", "name": "ref" }
  ],
  "trigger-rule": {
    "and": [
      {
        "match": {
          "type": "payload-hmac-sha256",
          "secret": "__WEBHOOK_SECRET__",
          "parameter": { "source": "header", "name": "X-Hub-Signature-256" }
        }
      },
      {
        "match": {
          "type": "regex",
          "regex": "<refPattern>",
          "parameter": { "source": "payload", "name": "ref" }
        }
      }
    ]
  }
}]
```

`__WEBHOOK_SECRET__` は ExecStartPre で `/run/secrets/webhook-secret` の値に置換される。HMAC secret が /nix/store に入ることはない。

### Secrets（Self-Deploy 用追加分）

```yaml
# secrets/ci.yaml (SOPS 暗号化)
github_deploy_key: |       # EC2 → GitHub SSH (git clone/pull)
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----

webhook_secret: <40-hex>   # GitHub → EC2 HMAC 署名検証
```

```nix
# secrets.nix (sops-nix 宣言)
secrets."github_deploy_key" = {
  sopsFile = ../secrets/ci.yaml;
  owner = "root";
  mode = "0600";
  path = "/run/secrets/github-deploy-key";
};

secrets."webhook_secret" = {
  sopsFile = ../secrets/ci.yaml;
  owner = "root";
  mode = "0400";
  path = "/run/secrets/webhook-secret";
};
```

### Secrets の環境分離

```
secrets/
├── infra.yaml               # 共通: DNS token, SSH deploy key, SSL cert
├── ci.yaml                  # 共通: github_deploy_key, webhook_secret
├── <project>-staging.yaml   # staging: DB URL, API keys
└── <project>-prod.yaml      # prod: DB URL, API keys
```

### nginx Webhook プロキシ

```nix
# application.nix (nginx 設定の一部)
locations."/.well-known/deploy" = {
  proxyPass = "http://127.0.0.1:9000/hooks/deploy";
  extraConfig = ''
    proxy_read_timeout 600;
  '';
};
```

GitHub webhook は `https://<domain>/.well-known/deploy` に POST する。nginx が `localhost:9000` に転送。

### flake.nix: マルチ環境 Hive

```nix
colmenaHive = colmena.lib.makeHive {
  meta.nixpkgs = import nixpkgs { system = "aarch64-linux"; };

  "<project>-prod" = { name, nodes, pkgs, ... }: {
    deployment = { targetHost = infraProd.host; targetUser = "root"; };
    imports = [ ./nixos/common.nix ./nixos/infrastructure.nix ./nixos/application.nix ];

    <project>.secretsEnvironment = "prod";
    <project>.deploy = {
      enable = true;
      nodeName = "<project>-prod";
      refPattern = "^refs/tags/v";          # v* タグのみ受理
    };
  };

  "<project>-staging" = { name, nodes, pkgs, ... }: {
    deployment = { targetHost = infraStaging.host; targetUser = "root"; };
    imports = [ ./nixos/common.nix ./nixos/infrastructure.nix ./nixos/application.nix ];

    <project>.secretsEnvironment = "staging";
    <project>.deploy = {
      enable = true;
      nodeName = "<project>-staging";
      refPattern = "^refs/heads/main$";     # main push のみ受理
    };
  };
};
```

### GitHub Actions: 検証のみ（デプロイしない）

```yaml
# .github/workflows/deploy.yml
name: Post-Deploy Verification

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  smoke-staging:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Wait for webhook deploy
        run: sleep 30
      - name: Smoke test staging
        run: bash tests/smoke/smoke.sh
        env:
          SMOKE_BASE_URL: "https://staging.<domain>"

  auto-release:
    needs: smoke-staging
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Generate version tag
        id: version
        run: echo "tag=v$(date +%Y%m%d.%H%M%S)" >> $GITHUB_OUTPUT
      - name: Create release tag
        run: |
          git tag ${{ steps.version.outputs.tag }}
          git push origin ${{ steps.version.outputs.tag }}

  smoke-production:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Wait for webhook deploy
        run: sleep 60
      - name: Smoke test production
        run: bash tests/smoke/smoke.sh
        env:
          SMOKE_BASE_URL: "https://app.<domain>"
```

GitHub Actions の役割は 3 つだけ:
1. **Smoke test**: デプロイ後の外部ヘルスチェック
2. **Auto-release**: staging smoke 成功 → `v{YYYYMMDD.HHMMSS}` タグ自動生成
3. **Production smoke**: タグ push 後の production ヘルスチェック

GitHub Actions Secrets に SSH key や AWS credentials は**不要**。

### GitHub Webhook 設定（手動）

```
GitHub repo → Settings → Webhooks:
  Payload URL:  https://<domain>/.well-known/deploy
  Content type: application/json
  Secret:       SOPS 内の webhook_secret と同じ値
  Events:       push のみ
```

### Terraform の環境分離

Terraform workspace または個別ディレクトリで staging/prod を分離する。

```
infra/terraform/
├── staging/
│   ├── main.tf
│   └── infra-<project>-staging.json   # 出力
└── prod/
    ├── main.tf
    └── infra-<project>-prod.json      # 出力
```

### Credential Matrix

| 操作 | 必要な認証情報 | 実行主体 | 頻度 |
|---|---|---|---|
| Staging deploy | なし（webhook 自動） | EC2 (webhook → apply-local) | 毎 main push |
| Production deploy | なし（webhook 自動） | EC2 (webhook → apply-local) | 毎タグ push |
| Post-deploy 検証 | なし | GitHub Actions | 毎 deploy 後 |
| ローカルデプロイ | SSH key | 開発者 (`colmena apply`) | デバッグ/緊急時 |
| Secret 編集 | AWS credentials (KMS) | 開発者 | 時々 |
| インフラ変更 | AWS credentials (admin) | 開発者 | 稀 |

### 横展開チェックリスト

新プロジェクトにこのパターンを適用する場合:

- [ ] `deploy.nix` をコピーして option 名と `repoUrl` を変更
- [ ] `secrets.nix` に `github_deploy_key` と `webhook_secret` を追加
- [ ] SOPS で `secrets/ci.yaml` を作成 — deploy key と webhook secret を暗号化
- [ ] GitHub で Deploy Key を登録（read-only SSH key）
- [ ] GitHub で Webhook を登録（push event, HMAC secret）
- [ ] flake.nix の Colmena ノードに `deploy.enable = true` + `refPattern` を設定
- [ ] nginx に `/.well-known/deploy` プロキシを追加
- [ ] `deploy.yml` を作成 — smoke test + auto-release（デプロイ自体は不要）
- [ ] EC2 の IAM Instance Profile に KMS `kms:Decrypt` 権限を確認

---

## 14. 同一 AWS アカウントでの複数プロジェクト共存

同一 AWS アカウント内で複数プロジェクトを安全に共存させる方法。

### 分離の仕組み

1. **VPC CIDR 分離**: プロジェクトごとに異なる CIDR を割り当てる。
   - Project A: `10.0.0.0/16`
   - Project B: `10.1.0.0/16`
   - Project C: `10.2.0.0/16`

2. **Tag-based scoping**: IAM policy で `Project=<project-name>` タグのリソースのみ操作可能にする。

3. **IAM path separation**: Developer IAM users を `/developers/<project>/` path 配下に作成する。

4. **KMS key 分離**: プロジェクトごとに独立した KMS key を使用する。

### Tag-based IAM Policy の実装

マルチテナント隔離の核心。開発者が自プロジェクトのリソースのみ操作可能にする。

#### 前提: 全リソースに `Project` タグを強制する

セクション 7 の Terraform 定義で `default_tags` を設定済み。これにより Terraform が作成する全リソースに `Project = "<project-name>"` タグが付与される。

#### `tfc-bootstrap/developers.tf` に追加する IAM Policy

```hcl
# === Tag-based Resource Scoping ===
# 開発者が自プロジェクトのリソースのみ操作可能にする

resource "aws_iam_policy" "project_scope" {
  name        = "<project-name>-project-scope"
  path        = "/developers/<project-name>/"
  description = "Restrict resource access to Project=<project-name> tagged resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- EC2: 閲覧は全リソース許可 (describe は tag filter 不可) ---
      {
        Sid    = "AllowDescribe"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
        ]
        Resource = "*"
      },
      # --- EC2: 変更操作は自プロジェクトのみ ---
      {
        Sid    = "AllowEC2MutationOnProject"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:CreateTags",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
        }
      },
      # --- EC2: 新規リソース作成時にタグを強制 ---
      {
        Sid    = "DenyCreateWithoutProjectTag"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateVpc",
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestTag/Project" = "<project-name>"
          }
        }
      },
      # --- KMS: 自プロジェクトの鍵のみ (セクション 6 の kms.tf と連動) ---
      # KMS policy (key policy) 側で既に制御しているため、
      # ここでは IAM policy 側の二重防御として記述
      {
        Sid    = "AllowKMSOnProjectKey"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource = aws_kms_key.sops.arn
      },
      # --- 他プロジェクトの KMS を明示的に拒否 ---
      {
        Sid    = "DenyKMSOnOtherKeys"
        Effect = "Deny"
        Action = "kms:*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
          # KMS key にタグがある場合のみ評価 (タグなし = AWS managed key は除外)
          Null = {
            "aws:ResourceTag/Project" = "false"
          }
        }
      },
    ]
  })
}

# 全開発者にアタッチ
resource "aws_iam_user_policy_attachment" "project_scope" {
  for_each   = toset(local.developers)
  user       = aws_iam_user.developer[each.key].name
  policy_arn = aws_iam_policy.project_scope.arn
}
```

#### 設計根拠

| 方針 | 理由 |
|------|------|
| `Describe*` は無条件許可 | AWS の Describe 系 API は `Condition` によるタグフィルタに対応していない。リソース一覧の閲覧を許可しても、変更操作がブロックされていれば安全。 |
| `Deny` + `StringNotEquals` で新規リソースにタグ強制 | `Allow` だけでは「タグなしで作成」を防げない。明示的 `Deny` により、`Project` タグなしのリソース作成を不可能にする。 |
| KMS は key policy + IAM policy の二重防御 | KMS は key policy が最終権限だが、IAM policy 側でも拒否することで、key policy の設定ミスによる横断アクセスを防止する。 |
| `Null` condition で managed key を除外 | `aws/ebs` 等の AWS managed KMS key には `Project` タグがないため、`Null` condition で「`Project` タグが存在する場合のみ」Deny を評価する。 |

#### 検証方法

```bash
# 1. 開発者の credentials で自プロジェクトの EC2 を操作できることを確認
AWS_PROFILE=<developer> aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=<project-name>"

# 2. 他プロジェクトの EC2 を停止できないことを確認
AWS_PROFILE=<developer> aws ec2 stop-instances \
  --instance-ids <other-project-instance-id>
# → AccessDeniedException

# 3. タグなしで EC2 を起動できないことを確認
AWS_PROFILE=<developer> aws ec2 run-instances \
  --image-id ami-xxx --instance-type t4g.nano
# → AccessDeniedException (Project タグ未指定)

# 4. 他プロジェクトの KMS key で暗号化できないことを確認
AWS_PROFILE=<developer> aws kms encrypt \
  --key-id <other-project-kms-arn> --plaintext "test"
# → AccessDeniedException
```

#### SCP (Service Control Policy) による組織レベルの強制

AWS Organizations を使用している場合、SCP で全アカウントに対してタグ強制を適用できる。個別の IAM policy よりも強力（IAM admin でも迂回不可）。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUntaggedResources",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "ec2:CreateVolume",
        "ec2:CreateSecurityGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestTag/Project": "true"
        }
      }
    }
  ]
}
```

SCP は Organizations の OU (Organizational Unit) にアタッチする。単一アカウント運用では IAM policy で十分。

### 新プロジェクト追加時のチェックリスト

- [ ] VPC CIDR が既存プロジェクトと重複しないこと
- [ ] KMS alias が一意であること (`alias/<project>-sops`)
- [ ] IAM path が一意であること (`/developers/<project>/`)
- [ ] Security Group 名が一意であること
- [ ] DNS サブドメインが一意であること
- [ ] Terraform state ファイルが分離されていること
- [ ] 全 Terraform リソースに `default_tags` で `Project` タグが設定されていること
- [ ] Tag-based IAM policy がプロジェクトの開発者にアタッチされていること
- [ ] 他プロジェクトのリソースへのアクセスが拒否されることを検証済みであること

---

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
# SSH 接続テスト
ssh -i ~/.ssh/<project>-deploy root@<EC2 IP>

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

**auto-release タグが生成されない**

- GitHub Actions の `deploy.yml` で `smoke-staging` が失敗していないか確認
- `auto-release` job に `permissions: contents: write` があるか確認
- Branch protection rules でタグ push がブロックされていないか確認

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
- [ ] SSH key pair を生成 (`ssh-keygen -t ed25519`)
- [ ] Bootstrap Terraform を作成 (`infra/tfc-bootstrap/`)
- [ ] Phase 1: KMS key を作成 (`terraform apply -target=aws_kms_key.sops`)
- [ ] `.sops.yaml` を作成（KMS ARN を設定）
- [ ] `secrets/infra.yaml` を暗号化して作成
- [ ] `secrets/<project>-<env>.yaml` を暗号化して作成
- [ ] Phase 3: Bootstrap apply（Developer IAM users 作成）
- [ ] メイン Terraform を作成・apply（VPC, EC2, DNS）
- [ ] Terraform output JSON を git commit
- [ ] NixOS 構成を作成 (`nixos/`, `flake.nix`)
- [ ] SSH config を設定（多重化 + 圧縮）
- [ ] `colmena apply` で初回デプロイ
- [ ] HTTPS アクセスを確認
- [ ] `.gitignore` に `*.tfstate*` を追加

### Self-Deploy Webhook セットアップ

- [ ] staging 用 EC2 を Terraform で作成（`infra/terraform/staging/`）
- [ ] `secrets/<project>-staging.yaml` を作成
- [ ] `secrets/ci.yaml` に `github_deploy_key` と `webhook_secret` を追加
- [ ] `deploy.nix` を作成（webhook + deploy script + repo init）
- [ ] `secrets.nix` に deploy key と webhook secret の宣言を追加
- [ ] flake.nix に staging/prod 両方の Colmena ターゲット + `deploy.enable` を定義
- [ ] nginx に `/.well-known/deploy` → `localhost:9000` プロキシを追加
- [ ] GitHub で Deploy Key を登録（read-only SSH key）
- [ ] GitHub で Webhook を登録（push event, HMAC secret）
- [ ] `.github/workflows/deploy.yml` を作成（smoke test + auto-release、デプロイしない）
- [ ] main push → staging 自動デプロイ → auto-release → prod 自動デプロイを検証

### 日常運用

- [ ] コード変更 → main に push → staging 自動デプロイ（webhook）
- [ ] auto-release → production 自動デプロイ（webhook + tag）
- [ ] 緊急時 → ローカル `colmena apply` で直接デプロイ
- [ ] Secret 変更 → `sops edit` → commit + push → 自動デプロイ
- [ ] インフラ変更 → `terraform apply` → JSON を git commit → 自動デプロイ

### 開発者の追加

- [ ] `locals.tf` に追加
- [ ] `git commit` + `push`
- [ ] `terraform apply`（Bootstrap）
- [ ] 新メンバーにセットアップ手順を共有

### セキュリティレビュー

- [ ] KMS key rotation が有効か (`enable_key_rotation = true`)
- [ ] EC2 IAM role が最小権限か（`Decrypt` + `DescribeKey` のみ）
- [ ] Developer IAM users が KMS 以外の権限を持っていないか
- [ ] SSH key が SOPS で暗号化されて git 管理されているか
- [ ] `.tfstate` ファイルが gitignore されているか
- [ ] Security Group で不要なポートが開いていないか
- [ ] `PermitRootLogin = "prohibit-password"` が設定されているか

---

## 付録: SOPS exec-env の仕組み

`sops exec-env` は SOPS ファイルのキーを環境変数として注入し、子プロセスを実行する。

```bash
# secrets/infra.yaml の内容:
#   cloudflare_api_token: "abc123"
#   cloudflare_zone_id: "zone456"
#   ssh_public_key: "ssh-ed25519 AAAA..."

sops exec-env secrets/infra.yaml -- terraform apply

# ↑ これは以下と等価:
# TF_VAR_cloudflare_api_token="abc123" \
# TF_VAR_cloudflare_zone_id="zone456" \
# TF_VAR_ssh_public_key="ssh-ed25519 AAAA..." \
# terraform apply
```

ただし `sops exec-env` はデフォルトでキー名をそのまま大文字の環境変数にする。Terraform の `TF_VAR_` プレフィックスが必要な場合は、`variables.tf` のキー名を `secrets/*.yaml` のキー名と一致させること。

実際には `sops exec-env` は `CLOUDFLARE_API_TOKEN` のように大文字化する場合があるため、Terraform の `variables.tf` では小文字のキー名を使い、プロバイダ側で環境変数名を指定する方法が安全。

```hcl
# variables.tf
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
```

```yaml
# secrets/infra.yaml
cloudflare_api_token: "abc123"
# → sops exec-env は CLOUDFLARE_API_TOKEN を設定
# → Terraform は TF_VAR_cloudflare_api_token を期待
# この不一致に注意。必要に応じてラッパースクリプトで変換する。
```

### ラッパースクリプト例（環境変数名の変換）

```bash
#!/usr/bin/env bash
# scripts/tf-apply.sh
set -euo pipefail

cd "$(dirname "$0")/../infra/terraform"

# SOPS で復号し、TF_VAR_ プレフィックスを追加
eval $(sops -d ../../secrets/infra.yaml | yq -r 'to_entries | .[] | "export TF_VAR_\(.key)=\(.value | @sh)"')

terraform "$@"
```

```bash
# 使い方
./scripts/tf-apply.sh plan
./scripts/tf-apply.sh apply
```
