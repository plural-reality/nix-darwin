## 10. 日常運用

ブートストラップ完了後、2 つのデプロイ方法が利用可能。

### 方法 1: ローカルデプロイ（手動）

ローカルの Nix Builder でビルドし、Cachix 経由で EC2 にデプロイする。

```
Developer Mac
  │
  ├─ nix run .#deploy
  │    ├─ nix build       (ローカルでビルド)
  │    ├─ cachix push      (Cachix に push)
  │    └─ colmena apply    (EC2 が Cachix から pull + activation)
  │
  └─ (フォールバック: nix run .#deploy-ssh)
       └─ colmena apply    (SSH nix-copy-closure で直接転送)
```

### 方法 2: Self-Deploy（自動）

main への push やタグ付きリリースに対して、EC2 が自動でデプロイする。
**事前に cachix push が完了している必要がある。**

```
Developer Mac
  │
  ├─ nix build + cachix push  (ビルド → Cachix に push)
  ├─ git push (main)          → EC2 staging: webhook → colmena apply-local (Cachix から pull)
  └─ git tag v* + push        → EC2 prod: webhook → colmena apply-local (Cachix から pull)
```

`nix run .#deploy` は build → cachix push → colmena apply を一括実行するため、
方法 1 を実行した後に `git push` すれば、方法 2 の Self-Deploy でも Cachix cache が warm な状態になる。

### 開発サイクル一覧

```
┌──────────────────────────────────────────────────────────────┐
│  コード変更 (方法 1):                                         │
│    nix run .#deploy (build → cachix push → colmena apply)    │
│                                                              │
│  コード変更 (方法 2):                                         │
│    nix run .#deploy → git push → EC2 自動デプロイ            │
│                                                              │
│  フォールバック:                                              │
│    nix run .#deploy-ssh (Cachix 障害時)                      │
│                                                              │
│  Secret 変更:                                                 │
│    sops edit → git commit → nix run .#deploy                 │
│                                                              │
│  インフラ変更:                                                │
│    *.tf 編集 → sops exec-env ... -- terraform apply          │
│    → JSON を git commit → nix run .#deploy                   │
│                                                              │
│  Bootstrap 変更 (稀):                                         │
│    locals.tf 編集 → sops exec-env ... -- terraform apply     │
│    (新しい IAM user/policy 追加、KMS policy 変更)             │
└──────────────────────────────────────────────────────────────┘
```

### コマンドリファレンス

```bash
# === 方法 1: ローカルデプロイ (デフォルト: Cachix 経由) ===
nix run .#deploy
# → build → cachix push → colmena apply (EC2 は Cachix から pull)

# === 方法 1: フォールバック (SSH 直接転送) ===
nix run .#deploy-ssh
# → colmena apply (SSH nix-copy-closure で直接転送)

# === 方法 2: Self-Deploy (自動) ===
nix run .#deploy    # まず Cachix に push
git push            # webhook が EC2 self-deploy を発火

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
# (Cachix auth token は deploy スクリプト内で SOPS から自動抽出される。手動設定不要)
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
nix run .#deploy
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

Cachix Binary Cache がデフォルトの転送手段。追加の最適化は以下の通り。

### デプロイパイプライン分析

```
nix run .#deploy
    │
    ├── 1. Nix evaluation          ~5s      (flake.nix → NixOS closure 計算)
    ├── 2. App derivation build    ~30-60s  (依存インストール + ビルド)
    ├── 3. NixOS closure build     ~10-30s  (system closure をリンク)
    ├── 4. cachix push             ~10-20s  (closure を Cachix に push)
    ├── 5. colmena apply           ~5-10s   (EC2 が Cachix から pull + activation)
    └── 6. Service restart         ~3-5s
                                   ─────────
                            合計: ~55-130s (typical)
                            Cache hit: ~15-25s (ビルド済みの場合)
```

従来の SSH `nix-copy-closure` と比較して:
- **Cachix push/pull は並列転送**で SSH の単一ストリーム転送より高速
- **Cache hit 時はステップ 2-4 がスキップ**される（他開発者がビルド済み等）
- EC2 上でのビルド負荷は**ゼロ**（substituter からの pull のみ）

### 追加最適化 1: ソースフィルタリング（効果: 大）

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

### 追加最適化 2: SSH 多重化 + 圧縮（効果: 中、フォールバック時）

SSH config で接続を再利用し、転送を圧縮する。Cachix 障害時の `deploy-ssh` フォールバックで有効。

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

### 最適化の優先順位

| 施策 | 作業量 | 効果 | 推奨時期 |
|------|--------|------|----------|
| Cachix Binary Cache | **デフォルト** | 大 | 初期セットアップ時 |
| ソースフィルタリング | 5分 | 大 | 即座に |
| SSH 多重化 | 5分 | 中 | 即座に |
| Self-Deploy Webhook | 2-3時間 | 大 (自動化) | staging/prod 分離時（セクション 13） |
