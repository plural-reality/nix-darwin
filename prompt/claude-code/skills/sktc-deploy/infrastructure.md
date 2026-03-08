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

# Developer 権限: 初回ブートストラップ後のすべての操作を開発者が実行可能にする
# ABAC (Attribute-Based Access Control): Project タグでスコープを制限
resource "aws_iam_user_policy" "developer" {
  for_each = toset(local.developers)
  name     = "project-manage"
  user     = aws_iam_user.developer[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- Bootstrap 層: 開発者の追加・削除 ---
      {
        Sid    = "ManageDeveloperUsers"
        Effect = "Allow"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:ListUsers",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:GetUserPolicy",
          "iam:ListUserPolicies",
        ]
        Resource = "arn:aws:iam::<account-id>:user/developers/<project-name>/*"
      },
      {
        Sid    = "ManageSOPSKeyPolicy"
        Effect = "Allow"
        Action = [
          "kms:PutKeyPolicy",
          "kms:GetKeyPolicy",
        ]
        Resource = aws_kms_key.sops.arn
      },
      # --- メイン層: インフラ管理 ---
      {
        Sid    = "ManageEC2"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          # VPC / Subnet / SG / IGW / Route / EIP
          "ec2:*Vpc*",
          "ec2:*Subnet*",
          "ec2:*SecurityGroup*",
          "ec2:*InternetGateway*",
          "ec2:*RouteTable*",
          "ec2:*Route",
          "ec2:*Address*",       # EIP
          "ec2:*KeyPair*",
          "ec2:*NetworkInterface*",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeAccountAttributes",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
        }
      },
      {
        Sid    = "EC2DescribeUntagged"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeAddresses",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeImages",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeNetworkInterfaces",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageIAMRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:TagRole",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = [
          "arn:aws:iam::<account-id>:role/<project-name>-*",
          "arn:aws:iam::<account-id>:instance-profile/<project-name>-*",
        ]
      },
      {
        Sid    = "ManageBackup"
        Effect = "Allow"
        Action = [
          "backup:*",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
        }
      },
    ]
  })
}

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
# sops exec-env は YAML キー名を大文字化して環境変数に設定する
# 例: cloudflare_api_token → CLOUDFLARE_API_TOKEN
# Terraform は TF_VAR_<name> を期待するため、ラッパースクリプトで変換する
# (後述の「Terraform 実行方法」セクションを参照)

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
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTP (Let's Encrypt ACME challenge + redirect)
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTPS
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 強制 (SSRF 防御)
    http_put_response_hop_limit = 1
  }

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

### Terraform 実行方法

`sops exec-env` は YAML のキー名を大文字化して環境変数に設定する（例: `cloudflare_api_token` → `CLOUDFLARE_API_TOKEN`）。
しかし Terraform は `TF_VAR_<variable_name>` 形式を期待する。この不一致を解決するラッパースクリプトを使用する。

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

### EBS バックアップ (AWS Backup)

```hcl
# backup.tf
resource "aws_backup_vault" "main" {
  name = "<project-name>-backup"
  tags = { Name = "<project-name>-backup" }
}

resource "aws_backup_plan" "daily" {
  name = "<project-name>-daily"

  rule {
    rule_name         = "daily-snapshot"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 * * ? *)"  # 毎日 03:00 UTC

    lifecycle {
      delete_after = 14  # 14 日間保持
    }
  }

  tags = { Name = "<project-name>-backup-plan" }
}

resource "aws_backup_selection" "ec2" {
  name          = "<project-name>-ec2"
  iam_role_arn  = aws_iam_role.backup.arn
  plan_id       = aws_backup_plan.daily.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = "<project-name>"
  }
}

resource "aws_iam_role" "backup" {
  name = "<project-name>-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })

  tags = { Project = "<project-name>" }
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
```
