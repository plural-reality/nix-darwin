## 15. Self-Deploy Webhook パイプライン — 完全実装リファレンス

### 設計思想

EC2 が GitHub webhook を直接受信し、自分自身をデプロイする（Self-Deploy）。外部 CI/CD サービスは一切不要。

中間ノードを排除することで:
- SSH private key を外部サービスに保存する必要がない
- CI runner のアーキテクチャ問題（x86_64 vs aarch64）が発生しない
- デプロイレイテンシが低い（webhook → 即実行）
- **cache hit 時は Cachix から pull、cache miss 時は EC2 上で build して push-back できる**

```
Developer or CI
  │
  ├─ (optional) nix build + cachix push   (Cachix を pre-warm)
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
  │                │    └─ cache hit: Cachix pull / cache miss: local build
  │                ├─ smoke test (localhost)
  │                ├─ Cachix push-back
  │                └─ rollback on failure
```

`cachix push` を `git push` より先に実行すると staging / prod の cache hit が増える。ただしこれは高速化であり、Self-Deploy の前提条件ではない。cache miss 時は EC2 上で build し、成功後に Cachix push-back で次回以降を高速化する。

### 環境モデル

| Git Event | Environment | refPattern | EC2 の動作 |
|---|---|---|---|
| `push to main` | Staging | `^refs/heads/main$` | git pull → `colmena apply-local` (cache hit 時 pull / miss 時 local build) → smoke test → push-back |
| `tag v*` | Production | `^refs/tags/v` | git checkout tag → `colmena apply-local` (staging の push-back で cache hit 可能) → smoke test → push-back |

staging は main の HEAD を常に追従。production はタグでのみ更新。

### 自動リリースフロー

```
Developer: git push (main)
  → EC2 staging: webhook → self-deploy (cache hit 時 pull / miss 時 local build)
  → smoke test → Cachix push-back
  → Developer: staging 確認 → git tag v* → git push --tags
  → EC2 prod: webhook → self-deploy (staging の push-back で cache hit 可能)
  → smoke test → Cachix push-back
```

---

### Part 1: Terraform — GitHub Webhook の自動プロビジョニング

Webhook の登録を手動（GitHub Console）で行うとドリフトの原因になる。GitHub Terraform Provider で宣言的に管理する。

#### 前提: GitHub Personal Access Token

Webhook を管理するには、対象リポジトリに `admin:repo_hook` スコープを持つ token が必要。これを SOPS で管理する。

```yaml
# secrets/infra.yaml に追加 (SOPS 暗号化)
github_token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
github_owner: "<github-org-or-user>"
github_repo: "<repo-name>"
```

#### `infra/terraform/variables.tf` に追加

```hcl
variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "webhook_secret" {
  type      = string
  sensitive = true
  # secrets/ci.yaml の webhook_secret と同じ値を注入する
  # tf-apply.sh で SOPS から TF_VAR_ に変換される
}
```

#### `infra/terraform/main.tf` に Provider 追加

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
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}
```

#### `infra/terraform/webhook.tf` — GitHub Webhook リソース

```hcl
# === GitHub Webhook: push → EC2 Self-Deploy ===
#
# GitHub から EC2 への通知経路:
#   GitHub push event
#     → POST https://<domain>/.well-known/deploy
#     → nginx reverse proxy → localhost:9000
#     → webhook binary (HMAC-SHA256 検証 + ref pattern match)
#     → trigger-deploy → deploy script (colmena apply-local)

resource "github_repository_webhook" "deploy" {
  repository = var.github_repo

  configuration {
    url          = "https://${local.domain}/.well-known/deploy"
    content_type = "json"
    secret       = var.webhook_secret
    insecure_ssl = false  # TLS 必須
  }

  active = true
  events = ["push"]  # push event のみ。PR merge も push として発火する。
}

# --- Staging 環境用 (staging が別ドメインの場合) ---
# staging と prod が同一 EC2 の場合は上記 1 つで十分（refPattern で分岐）。
# 別 EC2 の場合は以下を追加:

# resource "github_repository_webhook" "deploy_staging" {
#   repository = var.github_repo
#
#   configuration {
#     url          = "https://${local.staging_domain}/.well-known/deploy"
#     content_type = "json"
#     secret       = var.webhook_secret
#     insecure_ssl = false
#   }
#
#   active = true
#   events = ["push"]
# }
```

#### `infra/terraform/webhook.tf` — locals

```hcl
locals {
  # DNS ドメイン (outputs.tf の Colmena JSON にも使用)
  domain         = "<subdomain>.example.com"
  # staging_domain = "staging.<subdomain>.example.com"  # 別 EC2 の場合
}
```

#### Security Group: Webhook 用の追加ポートは不要

Webhook は HTTPS (443) 経由で nginx が受信し、`localhost:9000` に reverse proxy する。
セクション 7 の `network.tf` で既に port 443 が許可されているため、Security Group の追加変更は不要。

```
Internet → :443 (nginx, TLS) → localhost:9000 (webhook binary)
```

port 9000 は **localhost のみ** でリッスンする。外部からの直接アクセスは不可。

#### `scripts/tf-apply.sh` の更新

GitHub token と webhook secret を SOPS から注入する。既存の `tf-apply.sh` を拡張:

```bash
#!/usr/bin/env bash
# scripts/tf-apply.sh
set -euo pipefail

cd "$(dirname "$0")/../infra/terraform"

# SOPS で復号し、TF_VAR_ プレフィックスを追加
# infra.yaml: dns_api_token, dns_zone_id, ssh_public_key, github_token, github_owner, github_repo
eval $(sops -d ../../secrets/infra.yaml | yq -r 'to_entries | .[] | "export TF_VAR_\(.key)=\(.value | @sh)"')

# ci.yaml: webhook_secret (GitHub Webhook と EC2 の HMAC 検証で共有)
eval $(sops -d ../../secrets/ci.yaml | yq -r '{"webhook_secret": .webhook_secret} | to_entries | .[] | "export TF_VAR_\(.key)=\(.value | @sh)"')

terraform "$@"
```

#### Terraform 出力: Colmena 用 JSON に Webhook 情報を含める

```hcl
# outputs.tf (更新)
resource "local_file" "infra_json" {
  filename = "${path.module}/infra-<project>-<env>.json"
  content = jsonencode({
    host         = aws_eip.app.public_ip
    instance_id  = aws_instance.app.id
    hostname     = local.domain
    architecture = "aarch64"
    # webhook_url は参照情報のみ (NixOS 側で実際の設定に使う)
    webhook_url  = "https://${local.domain}/.well-known/deploy"
  })
}
```

---

### Part 2: EC2 側 — NixOS Self-Deploy モジュール 完全実装

#### ファイル構成

```
nixos/
├── deploy.nix          # Self-Deploy NixOS module (本セクションの主役)
├── common.nix          # SSH, firewall, Cachix substituter, base packages
├── infrastructure.nix  # AMI, swap, EBS
├── application.nix     # DB, App, nginx, SOPS, ACME
├── secrets.nix         # sops-nix シークレット宣言 (deploy 用を含む)
└── version.nix         # NixOS リビジョン配信 (/.well-known/version)
```

#### `nixos/deploy.nix` — 完全な NixOS モジュール

```nix
# nixos/deploy.nix
#
# Self-Deploy Webhook Module
#
# 責務:
#   1. deploy-repo-init: 初回 git clone (idempotent oneshot)
#   2. deploy-webhook:   GitHub webhook receiver (localhost:9000)
#   3. trigger-deploy:   非同期デプロイ起動 (systemd-run)
#   4. deploy script:    git fetch → colmena apply-local → smoke test → Cachix push-back → auto-rollback
#
# 外部依存:
#   - sops-nix: /run/secrets/github-deploy-key, /run/secrets/webhook-secret
#   - Cachix substituter: common.nix で設定済み
#   - colmena, git: common.nix の systemPackages で導入済み

{ config, pkgs, lib, ... }:

let
  cfg = config.<project>.deploy;

  # --- 定数 ---
  repoDir       = "/var/lib/<project>-deploy/repo";
  lockFile      = "/run/<project>-deploy.lock";
  webhookPort   = 9000;

  # --- SSH コマンド (GitHub Deploy Key 使用) ---
  gitSshCommand = "${pkgs.openssh}/bin/ssh -i /run/secrets/github-deploy-key -o StrictHostKeyChecking=accept-new";

  # --- Webhook hooks.json テンプレート ---
  #
  # __WEBHOOK_SECRET__ は ExecStartPre で /run/secrets/webhook-secret の値に動的置換される。
  # これにより HMAC secret が /nix/store (world-readable) に入ることを防止。
  #
  # trigger-rule の AND 条件:
  #   1. HMAC-SHA256 署名検証 (GitHub の X-Hub-Signature-256 ヘッダー)
  #   2. ref パターンマッチ (staging: ^refs/heads/main$, prod: ^refs/tags/v)
  hooksTemplate = pkgs.writeText "hooks-template.json" (builtins.toJSON [{
    id = "deploy";
    execute-command = toString triggerScript;
    pass-arguments-to-command = [
      { source = "payload"; name = "ref"; }
    ];
    trigger-rule = {
      "and" = [
        {
          match = {
            type      = "payload-hmac-sha256";
            secret    = "__WEBHOOK_SECRET__";
            parameter = { source = "header"; name = "X-Hub-Signature-256"; };
          };
        }
        {
          match = {
            type      = "regex";
            regex     = cfg.refPattern;
            parameter = { source = "payload"; name = "ref"; };
          };
        }
      ];
    };
  }]);

  # --- Trigger Script ---
  #
  # webhook binary は execute-command を同期実行する。
  # deploy は数分かかるため、systemd-run で非同期化し、
  # webhook が即座に HTTP 200 を返せるようにする。
  #
  # systemd-run は transient unit を生成する。
  # --collect: 完了後に自動クリーンアップ。
  # unit 名に timestamp を含めることで、複数の webhook が
  # 同時に到着した場合も unit 名が衝突しない
  # (実際のデプロイは flock で排他制御)。
  triggerScript = pkgs.writeShellScript "trigger-deploy" ''
    set -euo pipefail
    REF="$1"
    echo "Webhook received: ref=$REF, node=${cfg.nodeName}"

    systemd-run \
      --unit="${cfg.nodeName}-deploy-$(date +%s)" \
      --description="Deploy triggered by webhook (ref: $REF)" \
      --collect \
      ${toString deployScript} "$REF"

    echo "Deploy triggered for ref: $REF"
  '';

  # --- Deploy Script (本体) ---
  #
  # 処理フロー:
  #   1. flock で排他制御 (同時デプロイ防止)
  #   2. git fetch + checkout/pull
  #   3. 現在の generation を記録 (ロールバック用)
  #   4. colmena apply-local (cache hit 時は pull / miss 時は local build)
  #   5. smoke test (curl で health endpoint)
  #   6. Cachix push-back
  #   7. revision 検証
  #   8. 失敗時: 前の generation に自動ロールバック
  deployScript = pkgs.writeShellScript "deploy-${cfg.nodeName}" ''
    set -euo pipefail

    # === 1. 排他制御 ===
    # flock: 別のデプロイが実行中なら即座に終了。
    # webhook が短時間に複数回発火しても安全。
    exec 200>${lockFile}
    flock -n 200 || { echo "Deploy already running, skipping"; exit 0; }

    REF="$1"
    export GIT_SSH_COMMAND="${gitSshCommand}"
    cd "${repoDir}"

    echo "=== Deploy start: ref=$REF, node=${cfg.nodeName} ==="
    echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    # === 2. Git fetch + checkout ===
    git fetch origin

    case "$REF" in
      refs/tags/*)
        TAG="''${REF#refs/tags/}"
        echo "Checking out tag: $TAG"
        git checkout "$TAG"
        ;;
      refs/heads/*)
        BRANCH="''${REF#refs/heads/}"
        echo "Pulling branch: $BRANCH"
        git checkout "$BRANCH"
        git pull origin "$BRANCH" --ff-only
        ;;
      *)
        echo "ERROR: Unknown ref format: $REF"
        exit 1
        ;;
    esac

    echo "HEAD is now at: $(git rev-parse --short HEAD) ($(git log -1 --format='%s'))"

    # === 3. 現在の generation を記録 (ロールバック用) ===
    PREV_SYSTEM=$(readlink /run/current-system)
    echo "Previous system: $PREV_SYSTEM"

    # === 4. colmena apply-local ===
    # --node: 自分自身のノード名を指定
    # Cachix substituter が common.nix で設定されているため、
    # cache hit なら Cachix から pull され、cache miss 時のみ EC2 上でビルドされる。
    echo "=== Running colmena apply-local --node ${cfg.nodeName} ==="
    colmena apply-local --node "${cfg.nodeName}" --verbose

    # === 5. Smoke test ===
    echo "=== Running smoke test ==="
    if ! curl -sf --max-time 30 --retry 3 --retry-delay 5 \
        "http://localhost:${toString cfg.healthCheckPort}${cfg.healthCheckPath}"; then
      echo "ERROR: Smoke test failed!"
      echo "Rolling back to previous generation: $PREV_SYSTEM"
      "$PREV_SYSTEM/bin/switch-to-configuration" switch
      echo "Rollback complete. Previous generation restored."
      exit 1
    fi

    # === 6. Cachix push-back ===
    if [ -f /run/secrets/cachix-auth-token ]; then
      export CACHIX_AUTH_TOKEN=$(cat /run/secrets/cachix-auth-token)
      CURRENT_SYSTEM=$(readlink /run/current-system)
      nix-store -qR "$CURRENT_SYSTEM" | cachix push "${cfg.cachixCache}"
      echo "Pushed closure to Cachix."
    else
      echo "WARN: cachix-auth-token not found, skipping Cachix push-back."
    fi

    # === 7. Revision 検証 ===
    # version.nix が配信する /etc/nixos-version.json の configurationRevision と
    # 現在の git HEAD が一致することを確認する。
    # NixOS + colmena の構造上、ズレは「インフラ破損」レベルでしか起きないため、
    # 失敗してもロールバックはせず警告のみ出力する。
    DEPLOYED_REV=$(jq -r '.configurationRevision // "unknown"' /etc/nixos-version.json 2>/dev/null || echo "unknown")
    EXPECTED_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    echo "Expected revision: $EXPECTED_REV"
    echo "Deployed revision: $DEPLOYED_REV"
    if [ "$DEPLOYED_REV" = "dirty" ] || [ "$DEPLOYED_REV" = "unknown" ]; then
      echo "WARN: configurationRevision is '$DEPLOYED_REV' (tree was dirty or version.nix not loaded)"
    elif [ "$DEPLOYED_REV" != "$EXPECTED_REV" ]; then
      echo "WARN: Revision mismatch! Expected=$EXPECTED_REV, Got=$DEPLOYED_REV"
      echo "WARN: This may indicate a flake eval issue. Investigate manually."
    else
      echo "OK: Revision verified."
    fi

    echo "=== Deploy successful ==="
    echo "Smoke test passed. System is healthy."
    echo "Current system: $(readlink /run/current-system)"
  '';

in {

  # ===================================================
  #  Option 定義
  # ===================================================
  options.<project>.deploy = {
    enable = lib.mkEnableOption "self-deploy webhook";

    nodeName = lib.mkOption {
      type        = lib.types.str;
      description = "Colmena node name (colmena apply-local --node <name>)";
      example     = "<project>-prod";
    };

    refPattern = lib.mkOption {
      type        = lib.types.str;
      description = "Regex to match git ref in webhook payload";
      example     = "^refs/heads/main$";
    };

    repoUrl = lib.mkOption {
      type        = lib.types.str;
      description = "Git SSH clone URL";
      example     = "git@github.com:<org>/<repo>.git";
    };

    cachixCache = lib.mkOption {
      type        = lib.types.str;
      description = "Cachix cache name (cache read path と deploy 成功後の push-back の両方に使用)";
      example     = "<project>";
    };

    healthCheckPort = lib.mkOption {
      type        = lib.types.port;
      default     = 3000;
      description = "Application health check port";
    };

    healthCheckPath = lib.mkOption {
      type        = lib.types.str;
      default     = "/api/health";
      description = "Application health check URL path";
    };
  };

  # ===================================================
  #  サービス定義 (enable 時のみ有効)
  # ===================================================
  config = lib.mkIf cfg.enable {

    # -------------------------------------------------
    #  Service 1: deploy-repo-init
    # -------------------------------------------------
    #  初回起動時に git clone を実行する idempotent oneshot。
    #  既に .git が存在すれば何もしない。
    #  sops-nix.service の後に起動 (deploy key が必要)。
    systemd.services.deploy-repo-init = {
      description = "Clone deploy repository (oneshot, idempotent)";
      after    = [ "network-online.target" "sops-nix.service" ];
      requires = [ "sops-nix.service" ];
      wants    = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;

        ExecStart = pkgs.writeShellScript "clone-repo" ''
          set -euo pipefail

          # 既に clone 済みならスキップ
          if [ -d "${repoDir}/.git" ]; then
            echo "Repository already exists at ${repoDir}"
            exit 0
          fi

          echo "Cloning ${cfg.repoUrl} into ${repoDir}..."
          mkdir -p "$(dirname "${repoDir}")"
          export GIT_SSH_COMMAND="${gitSshCommand}"
          git clone "${cfg.repoUrl}" "${repoDir}"
          echo "Clone complete."
        '';
      };
    };

    # -------------------------------------------------
    #  Service 2: deploy-webhook
    # -------------------------------------------------
    #  adnanh/webhook バイナリを port 9000 (localhost) で起動。
    #  GitHub からの POST を受け、HMAC 検証 + ref マッチ後に
    #  triggerScript を実行する。
    #
    #  ExecStartPre で hooks.json テンプレートの __WEBHOOK_SECRET__ を
    #  /run/secrets/webhook-secret の値で動的置換する。
    #  これにより HMAC secret が /nix/store に入らない。
    systemd.services.deploy-webhook = {
      description = "GitHub webhook receiver for self-deploy";
      after    = [ "deploy-repo-init.service" "sops-nix.service" ];
      requires = [ "deploy-repo-init.service" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      # deploy script が使う外部コマンドを PATH に追加
      path = with pkgs; [
        cachix
        colmena
        git
        nix
        curl
        jq           # revision 検証 (/etc/nixos-version.json の parse)
        coreutils
        systemd      # systemd-run
      ];

      serviceConfig = {
        # hooks.json を RuntimeDirectory に生成 (HMAC secret を注入)
        ExecStartPre = pkgs.writeShellScript "generate-hooks" ''
          set -euo pipefail
          SECRET=$(cat /run/secrets/webhook-secret)
          sed "s|__WEBHOOK_SECRET__|$SECRET|g" \
            ${hooksTemplate} > /run/deploy-webhook/hooks.json
          echo "hooks.json generated with HMAC secret injected."
        '';

        ExecStart = lib.concatStringsSep " " [
          "${pkgs.webhook}/bin/webhook"
          "-hooks /run/deploy-webhook/hooks.json"
          "-port ${toString webhookPort}"
          "-ip 127.0.0.1"   # localhost のみ。nginx が外部からプロキシする。
          "-verbose"
        ];

        RuntimeDirectory = "deploy-webhook";
        Restart          = "always";
        RestartSec       = 5;

        # セキュリティ強化
        NoNewPrivileges = true;
        ProtectHome     = true;
        PrivateTmp      = true;
      };
    };

    # -------------------------------------------------
    #  nginx: Webhook reverse proxy
    # -------------------------------------------------
    #  /.well-known/deploy → localhost:9000/hooks/deploy
    #
    #  GitHub webhook は HTTPS POST で到着する。
    #  nginx は TLS 終端し、webhook binary に転送する。
    #  proxy_read_timeout を長めに設定 (triggerScript は即座に応答するが念のため)。
    services.nginx.virtualHosts."${config.networking.hostName}" = {
      # 注意: application.nix で定義されている virtualHost に locations を追加する形。
      # application.nix 側で virtualHost が定義されていない場合は、
      # ここで enableACME, forceSSL 等も設定する。
      locations."/.well-known/deploy" = {
        proxyPass = "http://127.0.0.1:${toString webhookPort}/hooks/deploy";
        extraConfig = ''
          # triggerScript は systemd-run で即座に応答するが、
          # webhook binary 自体の初期化遅延に備えて余裕を持たせる
          proxy_read_timeout 60;
          proxy_connect_timeout 10;

          # GitHub Webhook の IP レンジに制限する場合 (オプション):
          # https://api.github.com/meta の "hooks" フィールドを参照
          # allow 192.30.252.0/22;
          # allow 185.199.108.0/22;
          # allow 140.82.112.0/20;
          # allow 2a0a:a440::/29;
          # deny all;
        '';
      };
    };

    # -------------------------------------------------
    #  Firewall: 追加ポート不要
    # -------------------------------------------------
    # port 9000 は localhost のみ。nginx が :443 で受信し proxy する。
    # common.nix で allowedTCPPorts = [ 22 80 443 ] 設定済み。
  };
}
```

#### `nixos/secrets.nix` — Self-Deploy 用シークレット宣言

```nix
# nixos/secrets.nix
#
# sops-nix シークレット宣言。
# アプリケーション用シークレットは application.nix の sops ブロックで定義。
# ここでは Self-Deploy 固有のシークレットを定義する。

{ config, ... }:

{
  sops.secrets."github_deploy_key" = {
    sopsFile = ../secrets/ci.yaml;
    key      = "github_deploy_key";
    owner    = "root";
    mode     = "0600";
    path     = "/run/secrets/github-deploy-key";
    # deploy-repo-init と deploy-webhook が依存
  };

  sops.secrets."webhook_secret" = {
    sopsFile = ../secrets/ci.yaml;
    key      = "webhook_secret";
    owner    = "root";
    mode     = "0400";
    path     = "/run/secrets/webhook-secret";
    # deploy-webhook の ExecStartPre が参照
  };

  sops.secrets."cachix_auth_token" = {
    sopsFile = ../secrets/ci.yaml;
    key      = "cachix_auth_token";
    owner    = "root";
    mode     = "0400";
    path     = "/run/secrets/cachix-auth-token";
    # deploy script の Cachix push-back が参照
  };
}
```

#### `secrets/ci.yaml` の構造 (SOPS 暗号化)

```yaml
# secrets/ci.yaml (SOPS 暗号化、git 管理)
#
# Self-Deploy + Cachix 用シークレット。
# sops edit secrets/ci.yaml で編集。

# EC2 → GitHub SSH アクセス (git clone / git pull)
# secrets/ssh/deploy.yaml の Deploy Key とは別。
# ci.yaml に含める理由: sops-nix で /run/secrets/ に展開するため。
github_deploy_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
  ...
  -----END OPENSSH PRIVATE KEY-----

# GitHub → EC2 HMAC-SHA256 署名検証用
# webhook binary が GitHub からの POST を認証するために使用。
# Terraform の var.webhook_secret と同じ値。
webhook_secret: "a1b2c3d4e5f6..."

# Cachix push 用 auth token
# ローカル deploy は SOPS から自動抽出し、Self-Deploy は /run/secrets/cachix-auth-token
# として runtime 復号して push-back に使う。
cachix_auth_token: "eyJhbGciOiJIUzI1NiJ9..."
```

#### `flake.nix` — Colmena Hive + Self-Deploy 統合

```nix
{
  description = "<project-name> deployment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
      # Terraform が生成した JSON (環境ごとに分離)
      infraProd = builtins.fromJSON (
        builtins.readFile ./infra/terraform/prod/infra-<project>-prod.json
      );
      infraStaging = builtins.fromJSON (
        builtins.readFile ./infra/terraform/staging/infra-<project>-staging.json
      );

      # 共通 import リスト
      commonImports = [
        sops-nix.nixosModules.sops
        ./nixos/common.nix
        ./nixos/infrastructure.nix
        ./nixos/application.nix
        ./nixos/secrets.nix     # Self-Deploy 用シークレット宣言
        ./nixos/deploy.nix      # Self-Deploy モジュール
        ./nixos/version.nix     # NixOS リビジョン配信 (/.well-known/version)
      ];
    in {
      colmenaHive = colmena.lib.makeHive {
        meta = {
          nixpkgs = import nixpkgs {
            system = "aarch64-linux";
          };
        };

        # === Production ===
        "<project>-prod" = { name, nodes, pkgs, ... }: {
          deployment = {
            targetHost    = infraProd.host;
            targetUser    = "root";
            buildOnTarget = false;  # ローカルビルド
          };

          imports = commonImports;

          networking.hostName = "<project>-prod";

          # flake の git rev を version.nix が参照する configurationRevision に埋め込む
          system.configurationRevision = self.rev or self.dirtyRev or null;

          <project>.secretsEnvironment = "prod";
          <project>.deploy = {
            enable         = true;
            nodeName       = "<project>-prod";
            refPattern     = "^refs/tags/v";          # v* タグのみ受理
            repoUrl        = "git@github.com:<org>/<repo>.git";
            cachixCache    = "<project>";
            healthCheckPort = 3000;
            healthCheckPath = "/api/health";
          };
        };

        # === Staging ===
        "<project>-staging" = { name, nodes, pkgs, ... }: {
          deployment = {
            targetHost    = infraStaging.host;
            targetUser    = "root";
            buildOnTarget = false;
          };

          imports = commonImports;

          networking.hostName = "<project>-staging";

          system.configurationRevision = self.rev or self.dirtyRev or null;

          <project>.secretsEnvironment = "staging";
          <project>.deploy = {
            enable         = true;
            nodeName       = "<project>-staging";
            refPattern     = "^refs/heads/main$";     # main push のみ受理
            repoUrl        = "git@github.com:<org>/<repo>.git";
            cachixCache    = "<project>";
            healthCheckPort = 3000;
            healthCheckPath = "/api/health";
          };
        };
      };

      # === ローカルデプロイ用 App ===
      apps.aarch64-darwin.deploy = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy" ''
          set -euo pipefail
          TARGET="''${1:-<project>-prod}"
          COLMENA=${colmena.packages.aarch64-darwin.colmena}/bin/colmena

          if ! ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            echo "==> No SSH keys in agent, loading operator key..."
            ${pkgs.sops}/bin/sops exec-file \
              "secrets/ssh/operator.yaml" \
              '${pkgs.openssh}/bin/ssh-add {}'
          fi

          TARGET_HOST=$($COLMENA eval --impure \
            -E "{ nodes, ... }: (builtins.getAttr \"$TARGET\" nodes).config.deployment.targetHost" \
            2>/dev/null || echo "")
          REMOTE_TARGET=""
          PREV_SYSTEM=""
          EXPECTED_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
          if [ -n "$TARGET_HOST" ]; then
            REMOTE_TARGET="root@$TARGET_HOST"
            PREV_SYSTEM=$(${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
              'readlink /run/current-system' 2>/dev/null || echo "")
          fi

          echo "=== Building NixOS closure for $TARGET ==="
          RESULT=$(nix build ".#colmenaHive.nodes.\"$TARGET\".config.system.build.toplevel" \
            --print-out-paths --no-link)

          echo "=== Pushing to Cachix ==="
          export CACHIX_AUTH_TOKEN=$(${pkgs.sops}/bin/sops -d secrets/ci.yaml \
            | ${pkgs.yq-go}/bin/yq '.cachix_auth_token')
          echo "$RESULT" | ${pkgs.cachix}/bin/cachix push <project>

          echo "=== Deploying via Colmena ==="
          time "$COLMENA" apply --impure --on "$TARGET"

          if [ -z "$REMOTE_TARGET" ]; then
            echo "WARN: targetHost could not be resolved, skipping remote verification."
            echo "=== Done ==="
            exit 0
          fi

          echo "=== Smoke test ==="
          if ! ${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
            'curl -sf --max-time 30 --retry 3 --retry-delay 5 http://localhost:3000/api/health'; then
            echo "ERROR: Smoke test failed on $TARGET"
            if [ -n "$PREV_SYSTEM" ]; then
              echo "Rolling back to previous generation: $PREV_SYSTEM"
              ${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
                "$PREV_SYSTEM/bin/switch-to-configuration switch"
            fi
            exit 1
          fi

          DEPLOYED_REV=$(${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
            'jq -r .configurationRevision /etc/nixos-version.json 2>/dev/null || echo unknown')
          echo "Expected revision: $EXPECTED_REV"
          echo "Deployed revision: $DEPLOYED_REV"

          echo "=== Done ==="
        ''}";
      };

      # === フォールバック: SSH 直接転送 ===
      apps.aarch64-darwin.deploy-ssh = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy-ssh" ''
          set -euo pipefail
          TARGET="''${1:-<project>-prod}"
          COLMENA=${colmena.packages.aarch64-darwin.colmena}/bin/colmena

          if ! ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            echo "==> No SSH keys in agent, loading operator key..."
            ${pkgs.sops}/bin/sops exec-file \
              "secrets/ssh/operator.yaml" \
              '${pkgs.openssh}/bin/ssh-add {}'
          fi

          TARGET_HOST=$($COLMENA eval --impure \
            -E "{ nodes, ... }: (builtins.getAttr \"$TARGET\" nodes).config.deployment.targetHost" \
            2>/dev/null || echo "")
          REMOTE_TARGET=""
          PREV_SYSTEM=""
          EXPECTED_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
          if [ -n "$TARGET_HOST" ]; then
            REMOTE_TARGET="root@$TARGET_HOST"
            PREV_SYSTEM=$(${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
              'readlink /run/current-system' 2>/dev/null || echo "")
          fi

          echo "Deploying $TARGET via SSH (fallback)..."
          time "$COLMENA" apply --impure --on "$TARGET"

          if [ -z "$REMOTE_TARGET" ]; then
            echo "WARN: targetHost could not be resolved, skipping remote verification."
            exit 0
          fi

          echo "=== Smoke test ==="
          if ! ${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
            'curl -sf --max-time 30 --retry 3 --retry-delay 5 http://localhost:3000/api/health'; then
            echo "ERROR: Smoke test failed on $TARGET"
            if [ -n "$PREV_SYSTEM" ]; then
              echo "Rolling back to previous generation: $PREV_SYSTEM"
              ${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
                "$PREV_SYSTEM/bin/switch-to-configuration switch"
            fi
            exit 1
          fi

          DEPLOYED_REV=$(${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
            'jq -r .configurationRevision /etc/nixos-version.json 2>/dev/null || echo unknown')
          echo "Expected revision: $EXPECTED_REV"
          echo "Deployed revision: $DEPLOYED_REV"
        ''}";
      };

      # === SSH 鍵ロードユーティリティ ===
      apps.aarch64-darwin.ssh-load = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in toString (pkgs.writeShellScript "ssh-load" ''
          set -euo pipefail
          ${pkgs.sops}/bin/sops exec-file \
            "secrets/ssh/operator.yaml" \
            '${pkgs.openssh}/bin/ssh-add {}'
          echo "Loaded operator SSH key into agent."
        '');
      };
    };
}
```

---

### Part 3: ロールバック戦略

NixOS の generation 機能を活用した自動ロールバック。

```
colmena apply-local
  │
  ├─ 成功 → smoke test
  │           ├─ 成功 → Cachix push-back → revision verify → デプロイ完了
  │           └─ 失敗 → $PREV_SYSTEM/bin/switch-to-configuration switch
  │                      → 前の generation に即座に復帰
  └─ 失敗 → エラー終了 (変更なし)
```

deploy script の該当部分:

1. `colmena apply-local` 実行前に `/run/current-system` のシンボリックリンク先を `PREV_SYSTEM` に記録
2. `colmena apply-local` で新しい generation に切り替え
3. smoke test（`curl` で health endpoint を確認）
4. smoke test 成功後、`/run/current-system` の closure を Cachix に push-back
5. smoke test 失敗時、`$PREV_SYSTEM/bin/switch-to-configuration switch` で前の generation に復帰

NixOS の generation はイミュータブルであり、ロールバックはアトミック。前の generation のすべてのサービス定義・パッケージが即座に復元される。

---

### Part 4: Secrets の環境分離

```
secrets/
├── infra.yaml                 # 共通: DNS token, SSH pubkey, GitHub token
├── ci.yaml                    # 共通: github_deploy_key, webhook_secret, cachix_auth_token
├── ssh/
│   ├── operator.yaml          # 共有 SSH 秘密鍵 (開発者 → EC2)
│   └── deploy.yaml            # Deploy SSH 秘密鍵 (EC2 → GitHub)
├── <project>-staging.yaml     # staging: DB URL, API keys
└── <project>-prod.yaml        # prod: DB URL, API keys
```

| ファイル | 使用場所 | 使用タイミング |
|----------|----------|---------------|
| `ci.yaml` → `github_deploy_key` | EC2 (sops-nix → /run/secrets/) | git clone / git pull |
| `ci.yaml` → `webhook_secret` | EC2 (sops-nix → /run/secrets/) + Terraform (GitHub Webhook) | HMAC 検証 |
| `ci.yaml` → `cachix_auth_token` | 開発者ローカル (nix run .#deploy) + EC2 (sops-nix → /run/secrets/) | cachix push / push-back |
| `infra.yaml` → `github_token` | 開発者ローカル (terraform apply) | GitHub Webhook 登録 |

---

### Part 5: Credential Matrix

> セクション 5（`architecture.md`）の Credential Matrix を参照。

---

### Part 6: Terraform の環境分離

staging と prod が別 EC2 の場合、Terraform ディレクトリを分離する。

```
infra/terraform/
├── staging/
│   ├── main.tf                    # Provider (github provider 含む)
│   ├── variables.tf
│   ├── network.tf
│   ├── compute.tf
│   ├── iam.tf
│   ├── dns.tf
│   ├── webhook.tf                 # GitHub Webhook (staging URL)
│   ├── outputs.tf
│   └── infra-<project>-staging.json
└── prod/
    ├── main.tf
    ├── variables.tf
    ├── network.tf
    ├── compute.tf
    ├── iam.tf
    ├── dns.tf
    ├── webhook.tf                 # GitHub Webhook (prod URL)
    ├── outputs.tf
    └── infra-<project>-prod.json
```

同一 EC2 で staging/prod を refPattern で分岐する場合は、webhook.tf は 1 つで十分。

---

### Part 7: GitHub Webhook 設定の検証

Terraform apply 後、GitHub 側で webhook が正しく登録されたことを確認する。

```bash
# Terraform で確認
cd infra/terraform
terraform state show github_repository_webhook.deploy

# GitHub API で確認
gh api repos/<org>/<repo>/hooks --jq '.[].config.url'
# → https://<domain>/.well-known/deploy

# webhook の delivery history を確認
gh api repos/<org>/<repo>/hooks/<hook-id>/deliveries --jq '.[0] | {status, delivered_at}'
```

EC2 側のログ確認:

```bash
# webhook サービスの状態
ssh <project>-<env> systemctl status deploy-webhook

# webhook のリアルタイムログ
ssh <project>-<env> journalctl -u deploy-webhook -f

# deploy の実行ログ (transient unit)
ssh <project>-<env> journalctl -u '<project>-*-deploy-*' --since '1 hour ago'

# hooks.json の内容確認 (HMAC secret が注入されているか)
ssh <project>-<env> cat /run/deploy-webhook/hooks.json | jq '.[0].trigger-rule'
# → secret フィールドに実際の HMAC secret が入っていること (__WEBHOOK_SECRET__ が残っていたら NG)
```

---

### Part 8: 横展開チェックリスト

新プロジェクトにこのパターンを適用する場合:

#### Terraform 側

- [ ] `infra.yaml` に `github_token`, `github_owner`, `github_repo` を追加
- [ ] `ci.yaml` に `webhook_secret` (ランダム生成: `openssl rand -hex 20`) を追加
- [ ] `variables.tf` に GitHub 変数を追加
- [ ] `main.tf` に GitHub provider を追加
- [ ] `webhook.tf` を作成
- [ ] `scripts/tf-apply.sh` を更新 (ci.yaml からの webhook_secret 注入)
- [ ] `terraform apply` で webhook を自動登録

#### NixOS 側

- [ ] `ci.yaml` に `github_deploy_key` を追加 (Deploy Key の秘密鍵)
- [ ] GitHub で Deploy Key を登録（`ci.yaml` に対応する公開鍵, read-only）
- [ ] `secrets.nix` に deploy key, webhook secret, cachix auth token の sops-nix 宣言を追加
- [ ] `deploy.nix` をコピーして `<project>` 名を変更
- [ ] `common.nix` に Cachix substituter + trusted-public-keys を設定
- [ ] `common.nix` の systemPackages に `colmena`, `git`, `curl`, `cachix` を確認
- [ ] `flake.nix` に staging/prod ノードの `deploy.enable = true` + `refPattern` を定義
- [ ] `flake.nix` に `system.configurationRevision = self.rev or self.dirtyRev or null` を設定
- [ ] `version.nix` を `commonImports` に追加
- [ ] nginx の virtualHost に `/.well-known/deploy` プロキシを確認 (deploy.nix が自動設定)
- [ ] デプロイ後に `curl https://<domain>/.well-known/version` でリビジョンを確認
- [ ] `git push` だけで staging 自動デプロイを検証
- [ ] 必要なら `nix run .#deploy` または CI build で Cachix を pre-warm
- [ ] `git tag v*` → `git push --tags` で production 自動デプロイを検証

#### セキュリティ確認

- [ ] webhook binary が `127.0.0.1` のみでリッスンしていること (`-ip 127.0.0.1`)
- [ ] HMAC secret が /nix/store に入っていないこと (hooks.json は /run/ に生成)
- [ ] deploy key のパーミッションが 0600 であること
- [ ] webhook secret のパーミッションが 0400 であること
- [ ] EC2 の Security Group で port 9000 が外部に開いていないこと
