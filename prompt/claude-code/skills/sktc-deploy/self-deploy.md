## 13. Self-Deploy Webhook パイプライン

### 設計思想

EC2 が GitHub webhook を直接受信し、自分自身をデプロイする（Self-Deploy）。外部 CI/CD サービスは一切不要。

中間ノードを排除することで:
- SSH private key を外部サービスに保存する必要がない
- CI runner のアーキテクチャ問題（x86_64 vs aarch64）が発生しない
- デプロイレイテンシが低い（webhook → 即実行）
- **Cachix から pre-built closure を pull するため、EC2 上でのビルド負荷はゼロ**

```
Developer
  │
  ├─ nix build + cachix push   (ローカルでビルド → Cachix に push)
  │
  ├─ git push to main ────┐
  │  or git tag v*          │
  │                         ▼
  │              GitHub Webhook (push event)
  │                         │
  │                         ▼
  │              EC2 :9000 (webhook binary)
  │                ├─ HMAC-SHA256 署名検証
  │                ├─ ref パターンマッチ
  │                └─ trigger-deploy (systemd-run, non-blocking)
  │                         │
  │                         ▼
  │              deploy script (flock 排他)
  │                ├─ git fetch + checkout/pull
  │                ├─ colmena apply-local --node <name>
  │                │    └─ Cachix substituter から pre-built closure を pull
  │                └─ smoke test (localhost)
```

**重要**: `cachix push` は `git push` より先に実行する。EC2 が `colmena apply-local` を実行する際に、Cachix に pre-built closure が存在している必要がある。`nix run .#deploy` ラッパーはこの順序を自動化する。

### 環境モデル

| Git Event | Environment | refPattern | EC2 の動作 |
|---|---|---|---|
| `push to main` | Staging | `^refs/heads/main$` | git pull → `colmena apply-local` (Cachix から pull) |
| `tag v*` | Production | `^refs/tags/v` | git checkout tag → `colmena apply-local` (Cachix から pull) |

staging は main の HEAD を常に追従。production はタグでのみ更新。

### 自動リリースフロー

```
Developer: nix build → cachix push → git push (main)
  → EC2 staging: webhook → self-deploy (Cachix pull) → smoke test
  → Developer: staging 確認 → git tag v* → git push --tags
  → EC2 prod: webhook → self-deploy (Cachix pull) → smoke test
```

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

# deploy.nix の path に colmena を追加
systemd.services.deploy-webhook.path = [ pkgs.colmena pkgs.git pkgs.nix ];

# 3. Trigger script (non-blocking via systemd-run)
#    webhook binary は同期的に execute-command を実行するため、
#    deploy を systemd-run でバックグラウンド化する。
triggerScript = pkgs.writeShellScript "trigger-deploy" ''
  set -euo pipefail
  REF="$1"
  # systemd-run で非同期実行（webhook の応答を即座に返す）
  systemd-run --unit="${cfg.nodeName}-deploy-$(date +%s)" \
    --description="Deploy triggered by webhook (ref: $REF)" \
    --collect \
    ${deployScript} "$REF"
  echo "Deploy triggered for ref: $REF"
'';
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

# Cachix に pre-built closure が存在するか事前チェック
# (開発者が cachix push を忘れた場合のガード)
SYSTEM_DRV=$(nix eval --raw ".#colmenaHive.nodes.<node-name>.config.system.build.toplevel.drvPath" 2>/dev/null || true)
if [ -n "$SYSTEM_DRV" ]; then
  if ! nix store ls --store https://<project>.cachix.org "$SYSTEM_DRV" &>/dev/null; then
    echo "WARN: Pre-built closure not found in Cachix. Build may be slow or fail on low-memory EC2."
  fi
fi

# 現在の generation を記録（ロールバック用）
PREV_SYSTEM=$(readlink /run/current-system)

# colmena apply-local は Cachix substituter から pre-built closure を pull する
colmena apply-local --node <node-name> --verbose

# ローカル smoke test（失敗時は自動ロールバック）
if ! curl -sf --max-time 30 --retry 3 --retry-delay 5 \
    http://localhost:<port>/api/health; then
  echo "ERROR: Smoke test failed. Rolling back to previous generation..."
  "$PREV_SYSTEM/bin/switch-to-configuration" switch
  echo "Rollback complete. Previous generation restored."
  exit 1
fi

echo "Deploy successful. Smoke test passed."
```

#### ロールバック戦略

NixOS の generation 機能を活用した自動ロールバック。スモークテスト失敗時に前の generation に戻す。

デプロイスクリプトは以下の手順でロールバックを実現する:

1. `colmena apply-local` 実行前に、現在の system generation へのシンボリックリンク (`/run/current-system`) を `PREV_SYSTEM` に記録する
2. `colmena apply-local` で新しい generation に切り替える
3. smoke test (`curl` による health check) を実行する
4. smoke test 失敗時、`$PREV_SYSTEM/bin/switch-to-configuration switch` を呼び出して前の generation に復帰する

これにより、NixOS の不変な generation 管理を活用した安全なデプロイが実現される。ロールバックはアトミックであり、前の generation のすべてのサービス定義・パッケージが即座に復元される。

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

`execute-command` は `triggerScript`（上記）を指す。`triggerScript` は `systemd-run` で `deployScript` を非同期実行するため、
webhook は即座に HTTP 200 を返し、デプロイはバックグラウンドで進行する。

### Secrets（Self-Deploy 用）

```yaml
# secrets/ci.yaml (SOPS 暗号化)
webhook_secret: <40-hex>   # GitHub → EC2 HMAC 署名検証
cachix_auth_token: <token> # Cachix push 用 auth token (開発者のローカルで使用)
```

```
# secrets/ssh/deploy.yaml (SOPS 暗号化, --input-type binary)
# EC2 → GitHub SSH (git clone/pull) 用の秘密鍵
# GitHub の Deploy Keys に対応する公開鍵が登録されている
```

```nix
# secrets.nix (sops-nix 宣言)
secrets."github_deploy_key" = {
  sopsFile = ../secrets/ssh/deploy.yaml;
  format = "binary";
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
├── infra.yaml               # 共通: DNS token, SSH public key, SSL cert
├── ci.yaml                  # 共通: webhook_secret, cachix_auth_token
├── ssh/
│   ├── operator.yaml        # 開発者 SSH 秘密鍵 (共有, ロールベース)
│   └── deploy.yaml          # Self-Deploy 用 SSH 秘密鍵 (GitHub Deploy Key)
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
| ローカルビルド + Cachix push | Cachix auth token (SOPS) | 開発者 | 毎デプロイ |
| Staging deploy (自動) | なし（webhook + Cachix pull） | EC2 (webhook → apply-local) | 毎 main push |
| Production deploy (自動) | なし（webhook + Cachix pull） | EC2 (webhook → apply-local) | 毎タグ push |
| フォールバックデプロイ | SSH key | 開発者 (`colmena apply`) | 緊急時 |
| Secret 編集 | AWS credentials (KMS) | 開発者 | 時々 |
| インフラ変更 | AWS credentials (admin) | 開発者 | 稀 |

### 横展開チェックリスト

新プロジェクトにこのパターンを適用する場合:

- [ ] Cachix cache を作成 (`cachix create <project>`)
- [ ] `common.nix` に Cachix substituter + trusted-public-keys を追加
- [ ] `deploy.nix` をコピーして option 名と `repoUrl` を変更
- [ ] `secrets.nix` に `github_deploy_key`, `webhook_secret` を追加
- [ ] SOPS で `secrets/ci.yaml` を作成 — deploy key, webhook secret, cachix auth token を暗号化
- [ ] GitHub で Deploy Key を登録（read-only SSH key）
- [ ] GitHub で Webhook を登録（push event, HMAC secret）
- [ ] flake.nix の Colmena ノードに `deploy.enable = true` + `refPattern` を設定
- [ ] flake.nix の `deploy` app に cachix push ステップを含める
- [ ] nginx に `/.well-known/deploy` プロキシを追加
- [ ] EC2 の IAM Instance Profile に KMS `kms:Decrypt` 権限を確認
