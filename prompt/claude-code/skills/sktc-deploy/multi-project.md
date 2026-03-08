## 16. 同一 AWS アカウントでの複数プロジェクト共存

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

> **注**: Developer IAM Policy の完全な定義はセクション 7（`infrastructure.md`）の `developers.tf` を参照。
> 以下はその設計根拠を説明する。

#### 設計根拠

| 方針 | 理由 |
|------|------|
| `Describe*` は無条件許可 | AWS の Describe 系 API は `Condition` によるタグフィルタに非対応。閲覧可能でも変更不可なら安全。 |
| 既存リソースの変更は `ResourceTag` で制御 | Delete/Modify/Authorize 等の操作は、対象リソースに `Project` タグがある場合のみ許可。 |
| 新規リソースの作成は `RequestTag` で制御 | `CreateVpc`, `CreateSubnet`, `RunInstances` 等は、まだリソースが存在しないため `ResourceTag` が使えない。`RequestTag`（tag-on-create）で制御する。 |
| `CreateTags` を独立 Statement で制御 | 既存リソースへのタグ追加（`ResourceTag`）と新規作成時の tag-on-create（`ec2:CreateAction`）を分離。 |
| `DeleteTags` で `Project` キーを Deny | タグ削除によるリソース「孤児化」を防止。Project タグが消えるとタグベースポリシー全体が無効化される。 |
| `RunInstances` をリソース ARN パターンで分割 | 新規リソース (instance/volume) は `RequestTag` で、既存リソース (subnet/sg) は `ResourceTag` で制御。`Resource = "*"` では他プロジェクトの VPC リソースを参照できてしまう。 |
| Route 操作は RouteTable の ResourceTag で制御 | `CreateRoute`/`DeleteRoute` は route-table リソースに対して `ResourceTag` 条件が使えるため、自プロジェクトの RouteTable のみ操作可能。 |
| NixOS AMI を `ec2:Owner` で別途許可 | Community AMI には `Project` タグがないため、AMI 所有者 ID で許可する。 |
| `Deny` で新規リソースにタグ強制 (2段) | `StringNotEquals` は key absent 時に評価されないため、`Null` 条件で「タグ未指定」も別途 Deny する。 |
| KMS は key policy + IAM policy の二重防御 | key policy の設定ミスによる横断アクセスを IAM policy 側でも防止。 |
| `Null` condition で managed key を除外 | `aws/ebs` 等の AWS managed KMS key には `Project` タグがないため。 |

#### ABAC の限界と緩和策

タグベース ABAC は同一アカウント内の論理分離として有効だが、以下の限界がある:

| 限界 | リスク | 緩和策 |
|------|--------|--------|
| IAM 権限があればポリシーを変更可能 | 開発者が自分の IAM policy を変更して制約を回避（自分の user も `/developers/<project>/*` パスに存在するため、policy の attach/detach が可能） | 信頼できるチーム前提の設計。信頼レベルが低い場合は SCP で IAM 変更自体を制限するか、AWS アカウント分離を推奨。 |
| Cloudflare DNS はプロジェクト分離なし | SOPS 経由で共通の API token を共有するため、全プロジェクトの DNS レコードを変更可能 | Cloudflare API token をプロジェクトごとに分離するか、Zone を分離する。信頼できるチームなら許容範囲。 |
| Terraform local state の同時 apply | 複数の開発者が同時に `terraform apply` すると state が競合する | 実運用では同時 apply は稀。チーム拡大時は S3 backend + DynamoDB state locking に移行。 |
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
