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
# === Tag-based Resource Scoping (ABAC) ===
# 開発者が自プロジェクトのリソースのみ操作可能にする。
#
# ABAC の 4 層防御:
#   1. Allow: Describe (読み取り) は全リソース許可
#   2. Allow: 変更操作は aws:ResourceTag/Project = 自プロジェクト のみ
#   3. Deny:  新規作成は aws:RequestTag/Project = 自プロジェクト でないと拒否
#   4. Deny:  Project タグの改竄・削除を明示的に拒否

resource "aws_iam_policy" "project_scope" {
  name        = "<project-name>-project-scope"
  path        = "/developers/<project-name>/"
  description = "ABAC: Restrict resource access to Project=<project-name>"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── 層 1: 読み取り (全リソース) ──────────────────────
      # Describe 系 API は aws:ResourceTag condition に非対応。
      # 一覧が見えても変更不可なら情報漏洩リスクは低い。
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

      # ── 層 2: 変更操作 (自プロジェクトリソースのみ) ───────
      # CreateTags は別 Statement で制御するため、ここには含めない。
      {
        Sid    = "AllowEC2MutationOnProject"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
        }
      },

      # ── 層 2b: タグ操作 (自プロジェクトリソース + 値の制限) ─
      # CreateTags は 2 つの条件を同時に満たす必要がある:
      #   - 対象リソースが自プロジェクトであること (ResourceTag)
      #   - 設定する Project タグ値が自プロジェクト名であること (RequestTag)
      # これにより、自リソースの Project タグを他プロジェクト名に書き換える攻撃を防止。
      {
        Sid    = "AllowCreateTagsOnOwnResources"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
          # Project タグを設定する場合、値は自プロジェクト名のみ許可
          "StringEqualsIfExists" = {
            "aws:RequestTag/Project" = "<project-name>"
          }
        }
      },

      # ── 層 2c: RunInstances (新規リソース + 既存リソース参照) ─
      # RunInstances は複数のリソースタイプを同時に作成/参照する。
      # 新規リソース (instance, volume) → aws:RequestTag で制御
      # 既存リソース (subnet, sg, key-pair) → aws:ResourceTag で制御
      {
        Sid    = "AllowRunInstancesNewResources"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:network-interface/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = "<project-name>"
          }
        }
      },
      {
        Sid    = "AllowRunInstancesExistingResources"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:aws:ec2:*:*:subnet/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:key-pair/*",
          "arn:aws:ec2:*::image/*",
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
        }
      },
      # AMI は NixOS Community 提供のため Project タグなし → 別途許可
      {
        Sid    = "AllowRunInstancesNixOSAMI"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*::image/*"
        Condition = {
          StringEquals = {
            "ec2:Owner" = "427812963091"  # NixOS Community AMIs
          }
        }
      },

      # ── 層 3: 新規作成にタグ強制 ────────────────────────
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

      # ── 層 4a: Project タグの削除を禁止 ─────────────────
      # Project タグが削除されるとリソースが「孤児」になり、
      # タグベースポリシー全体が崩壊する。
      {
        Sid    = "DenyDeleteProjectTag"
        Effect = "Deny"
        Action = "ec2:DeleteTags"
        Resource = "*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "aws:TagKeys" = "Project"
          }
        }
      },

      # ── 層 4b: Project タグの値改竄を禁止 ───────────────
      # 自リソースの Project タグを他プロジェクト名に書き換える攻撃を
      # Deny で明示的にブロック (層 2b の Allow 条件と二重防御)。
      {
        Sid    = "DenyCreateTagsWrongProject"
        Effect = "Deny"
        Action = "ec2:CreateTags"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestTag/Project" = "<project-name>"
          }
          # Project タグを含むリクエストのみ評価
          "ForAnyValue:StringEquals" = {
            "aws:TagKeys" = "Project"
          }
        }
      },

      # ── KMS: 自プロジェクトの鍵のみ ────────────────────
      # key policy 側で既に制御しているが、IAM policy で二重防御。
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
      {
        Sid    = "DenyKMSOnOtherKeys"
        Effect = "Deny"
        Action = "kms:*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:ResourceTag/Project" = "<project-name>"
          }
          # KMS key にタグがある場合のみ評価 (AWS managed key は除外)
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
| `Describe*` は無条件許可 | AWS の Describe 系 API は `Condition` によるタグフィルタに非対応。閲覧可能でも変更不可なら安全。 |
| `CreateTags` を独立 Statement で制御 | `ResourceTag`（対象リソースが自分のものか）と `RequestTag`（設定する値が正しいか）の両方を検証する必要があるため、他の変更操作と分離する。 |
| `DeleteTags` で `Project` キーを Deny | タグ削除によるリソース「孤児化」を防止。Project タグが消えるとタグベースポリシー全体が無効化される。 |
| `RunInstances` をリソース ARN パターンで分割 | 新規リソース (instance/volume) は `RequestTag` で、既存リソース (subnet/sg) は `ResourceTag` で制御。`Resource = "*"` では他プロジェクトの VPC リソースを参照できてしまう。 |
| NixOS AMI を `ec2:Owner` で別途許可 | Community AMI には `Project` タグがないため、AMI 所有者 ID で許可する。 |
| `Deny` + `StringNotEquals` で新規リソースにタグ強制 | `Allow` だけでは「タグなしで作成」を防げない。明示的 `Deny` が必要。 |
| KMS は key policy + IAM policy の二重防御 | key policy の設定ミスによる横断アクセスを IAM policy 側でも防止。 |
| `Null` condition で managed key を除外 | `aws/ebs` 等の AWS managed KMS key には `Project` タグがないため。 |

#### ABAC の限界と緩和策

タグベース ABAC は同一アカウント内の論理分離として有効だが、以下の限界がある:

| 限界 | リスク | 緩和策 |
|------|--------|--------|
| IAM admin 権限があればポリシーを変更可能 | 開発者が自分の IAM policy を変更して制約を回避 | 開発者に IAM 変更権限を与えない。IAM は bootstrap operator のみ。 |
| 全 AWS サービスがタグ条件に対応していない | 将来サービス追加時にタグ制御が効かない | サービス追加時に ABAC 対応を確認。未対応なら別ポリシーで制御。 |
| VPC Peering / Transit Gateway | VPC 間通信が設定されると論理分離が崩壊 | VPC Peering を Deny する SCP を適用。 |
| 最終的な分離は AWS アカウント分離 | タグベースは「信頼できるチーム」前提の論理分離 | プロジェクト間の信頼レベルが低い場合は AWS Organizations でアカウント分離を推奨。 |

#### 検証方法

```bash
# 1. 自プロジェクトの EC2 を操作できること
AWS_PROFILE=<developer> aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=<project-name>"

# 2. 他プロジェクトの EC2 を停止できないこと
AWS_PROFILE=<developer> aws ec2 stop-instances \
  --instance-ids <other-project-instance-id>
# → AccessDeniedException

# 3. タグなしで EC2 を起動できないこと
AWS_PROFILE=<developer> aws ec2 run-instances \
  --image-id ami-xxx --instance-type t4g.nano
# → AccessDeniedException (Project タグ未指定)

# 4. 他プロジェクトの Subnet を使えないこと
AWS_PROFILE=<developer> aws ec2 run-instances \
  --image-id ami-xxx --instance-type t4g.nano \
  --subnet-id <other-project-subnet-id> \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Project,Value=<project-name>}]"
# → AccessDeniedException (Subnet の ResourceTag/Project が不一致)

# 5. Project タグを削除できないこと
AWS_PROFILE=<developer> aws ec2 delete-tags \
  --resources <own-instance-id> --tags Key=Project
# → AccessDeniedException

# 6. Project タグを他プロジェクト名に書き換えられないこと
AWS_PROFILE=<developer> aws ec2 create-tags \
  --resources <own-instance-id> --tags Key=Project,Value=<other-project>
# → AccessDeniedException

# 7. 他プロジェクトの KMS key で暗号化できないこと
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
    },
    {
      "Sid": "DenyProjectTagDeletion",
      "Effect": "Deny",
      "Action": "ec2:DeleteTags",
      "Resource": "*",
      "Condition": {
        "ForAnyValue:StringEquals": {
          "aws:TagKeys": "Project"
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
- [ ] **VPC リソース (Subnet, SG, Key Pair) にも `Project` タグが付与されていること**
- [ ] Tag-based IAM policy がプロジェクトの開発者にアタッチされていること
- [ ] 他プロジェクトのリソースへのアクセスが拒否されることを検証済みであること
- [ ] **Project タグの削除・改竄が拒否されることを検証済みであること**
- [ ] **他プロジェクトの Subnet/SG を参照した RunInstances が拒否されることを検証済みであること**
