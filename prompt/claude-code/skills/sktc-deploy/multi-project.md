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
