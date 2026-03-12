## 8. NixOS 構成

### `flake.nix`（Colmena Hive 定義）

```nix
{
  description = "<project-name> deployment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";  # stable
    nix-filter.url = "github:numtide/nix-filter";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-filter, sops-nix, colmena, ... }:
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

          _module.args = {
            inherit nix-filter;
          };

          # NixOS の hostname
          networking.hostName = "<project>-<env>";
        };
      };

      # 便利: nix run .#deploy
      # deploy pipeline:
      #   Resolve dependencies → build → cachix push → colmena apply
      #   → smoke test → revision verify → failure 時は remote rollback
      # Cachix は高速化層であり、deploy の前提条件ではない。
      apps.aarch64-darwin.deploy = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy" ''
          set -euo pipefail
          COLMENA=${colmena.packages.aarch64-darwin.colmena}/bin/colmena

          if ! ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            echo "==> No SSH keys in agent, loading operator key..."
            ${pkgs.sops}/bin/sops exec-file \
              "secrets/ssh/operator.yaml" \
              '${pkgs.openssh}/bin/ssh-add {}'
          fi

          TARGET_HOST=$($COLMENA eval --impure \
            -E '{ nodes, ... }: (builtins.getAttr "<project>-<env>" nodes).config.deployment.targetHost' \
            2>/dev/null || echo "")
          REMOTE_TARGET=""
          PREV_SYSTEM=""
          EXPECTED_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
          if [ -n "$TARGET_HOST" ]; then
            REMOTE_TARGET="root@$TARGET_HOST"
            PREV_SYSTEM=$(${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
              'readlink /run/current-system' 2>/dev/null || echo "")
          fi

          echo "=== Building NixOS closure ==="
          RESULT=$(nix build '.#colmenaHive.nodes."<project>-<env>".config.system.build.toplevel' --print-out-paths --no-link)

          echo "=== Pushing to Cachix ==="
          export CACHIX_AUTH_TOKEN=$(${pkgs.sops}/bin/sops -d secrets/ci.yaml | ${pkgs.yq-go}/bin/yq '.cachix_auth_token')
          echo "$RESULT" | ${pkgs.cachix}/bin/cachix push <project>

          echo "=== Deploying via Colmena ==="
          time "$COLMENA" apply --impure --on <project>-<env> "$@"

          if [ -z "$REMOTE_TARGET" ]; then
            echo "WARN: targetHost could not be resolved, skipping remote verification."
            exit 0
          fi

          echo "=== Smoke test ==="
          if ! ${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
            'curl -sf --max-time 30 --retry 3 --retry-delay 5 http://localhost:3000/api/health'; then
            echo "ERROR: Smoke test failed"
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

      # フォールバック: Cachix 障害時に SSH 直接転送でデプロイ
      apps.aarch64-darwin.deploy-ssh = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy-ssh" ''
          set -euo pipefail
          COLMENA=${colmena.packages.aarch64-darwin.colmena}/bin/colmena

          if ! ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            echo "==> No SSH keys in agent, loading operator key..."
            ${pkgs.sops}/bin/sops exec-file \
              "secrets/ssh/operator.yaml" \
              '${pkgs.openssh}/bin/ssh-add {}'
          fi

          TARGET_HOST=$($COLMENA eval --impure \
            -E '{ nodes, ... }: (builtins.getAttr "<project>-<env>" nodes).config.deployment.targetHost' \
            2>/dev/null || echo "")
          REMOTE_TARGET=""
          PREV_SYSTEM=""
          EXPECTED_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
          if [ -n "$TARGET_HOST" ]; then
            REMOTE_TARGET="root@$TARGET_HOST"
            PREV_SYSTEM=$(${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
              'readlink /run/current-system' 2>/dev/null || echo "")
          fi

          echo "Deploying <project-name> via SSH (fallback)..."
          time "$COLMENA" apply --impure --on <project>-<env> "$@"

          if [ -z "$REMOTE_TARGET" ]; then
            echo "WARN: targetHost could not be resolved, skipping remote verification."
            exit 0
          fi

          echo "=== Smoke test ==="
          if ! ${pkgs.openssh}/bin/ssh "$REMOTE_TARGET" \
            'curl -sf --max-time 30 --retry 3 --retry-delay 5 http://localhost:3000/api/health'; then
            echo "ERROR: Smoke test failed"
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

      # 手動 SSH 接続だけ必要な場合のユーティリティ
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

### `buildOnTarget` と `colmena apply-local` の関係

| コマンド | ビルド場所 | `buildOnTarget` の効果 |
|---|---|---|
| `colmena apply` (リモートデプロイ) | `false`: ローカル → SSH 転送, `true`: EC2 上 | **有効** |
| `colmena apply-local` (Self-Deploy) | 常に EC2 上（ただし Cachix substituter から pull） | **無関係** |

Self-Deploy では `colmena apply-local` を使用するため、`buildOnTarget` フラグは影響しない。
EC2 はまず Cachix substituter を参照し、cache miss 時のみローカル build にフォールバックする。
`buildOnTarget` は `colmena apply`（リモートデプロイ / フォールバック）時のみ関係する。

### `deploy.nix` の必須 option

`deploy.nix` は deploy mode の定義であり、最適化の有無とは独立して成立しなければならない。そのため `cachixCache` は optional optimization ではなく、cache read path と push-back path の両方を束ねる必須パラメータとして扱う。

```nix
<project>.deploy = {
  enable      = true;
  nodeName    = "<project>-prod";
  repoUrl     = "git@github.com:<org>/<repo>.git";
  refPattern  = "^refs/tags/v";
  cachixCache = "<project>";  # read path + push-back path
};
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

  # === Authorized Keys ===
  # operator key の公開鍵 (bootstrap Phase 0 で生成した /tmp/operator.pub の内容)
  # 秘密鍵は secrets/ssh/operator.yaml に SOPS 暗号化で格納
  # 個人の識別は SSH 鍵ではなく AWS IAM (KMS Decrypt 権限) で行う
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... operator"  # secrets/ssh/operator.yaml に対応する公開鍵
  ];

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

      # EC2 が Cachix + cache.nixos.org から直接パッケージを取得
      # → cache hit 時は pull、cache miss 時は local build 後に push-back
      substituters = [
        "https://<project>.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "<project>.cachix.org-1:XXXXX..."
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
    git          # Self-Deploy の git clone/pull で必要
    colmena      # Self-Deploy の colmena apply-local で必要
    cachix       # Self-Deploy の push-back で必要
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
{ config, pkgs, lib, nix-filter, ... }:

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

    # ソースフィルタリング (純粋な最適化。deploy semantics は変えない)
    src = nix-filter.lib {
      root = ../.;
      include = [
        "src"
        "package.json"
        "package-lock.json"
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

  # 注意: NixOS 25.05 以降では ensurePermissions が廃止される可能性がある。
  # その場合は initialScript で GRANT を実行する:
  #   services.mysql.initialScript = pkgs.writeText "init.sql" ''
  #     GRANT ALL PRIVILEGES ON ${dbName}.* TO '${dbUser}'@'localhost';
  #     FLUSH PRIVILEGES;
  #   '';

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

### `nixos/version.nix`（NixOS リビジョン配信）

NixOS の `configurationRevision`（flake の git rev）を HTTP エンドポイントとして配信するモジュール。
デプロイ後に「実際に何が動いているか」を外部から問い合わせ可能にする。

```nix
# nixos/version.nix
#
# NixOS Revision Endpoint
#
# 責務:
#   1. /etc/nixos-version.json をビルド時に生成
#   2. /.well-known/version で nginx 経由配信
#
# NixOS + colmena の構造上、configurationRevision が示すリビジョンと
# 実際にメモリに載って動いているプロセスのリビジョンは実質的に等価:
#   - Nix store は content-addressed → バイナリが変われば store path が変わる
#   - store path が変われば ExecStart が変わる → systemd が restart する
#   - configurationRevision = self.rev (flake.nix で設定)
#
# ズレが起きるのは「インフラ自体が壊れた」レベル (store corruption, OOM kill 等) のみ。

{ config, pkgs, lib, ... }:

let
  versionJson = builtins.toJSON {
    configurationRevision = config.system.configurationRevision or "dirty";
    nixosVersion = config.system.nixos.version;
    hostname = config.networking.hostName;
  };

  versionFile = pkgs.writeText "nixos-version.json" versionJson;
in {
  # === /etc/nixos-version.json (ビルド時に確定) ===
  environment.etc."nixos-version.json".source = versionFile;

  # === nginx: /.well-known/version ===
  # application.nix の virtualHost に location を追加する形。
  # deploy.nix の /.well-known/deploy と同じパターン。
  services.nginx.virtualHosts."${config.networking.hostName}" = {
    locations."/.well-known/version" = {
      alias = "/etc/nixos-version.json";
      extraConfig = ''
        default_type application/json;
        add_header Cache-Control "no-cache, no-store";
        add_header X-Content-Type-Options nosniff;
      '';
    };
  };
}
```

#### 使用方法

```bash
# HTTP 経由で確認
curl -s https://<domain>/.well-known/version | jq
# → { "configurationRevision": "a1b2c3d...", "nixosVersion": "25.05...", "hostname": "<project>-prod" }

# SSH 経由で直接確認 (nginx を経由しない)
ssh <project>-<env> cat /etc/nixos-version.json | jq

# /run/current-system と照合 (NixOS generation の真実)
ssh <project>-<env> readlink /run/current-system
```

#### flake.nix への統合

```nix
# commonImports に version.nix を追加
commonImports = [
  sops-nix.nixosModules.sops
  ./nixos/common.nix
  ./nixos/infrastructure.nix
  ./nixos/application.nix
  ./nixos/secrets.nix
  ./nixos/deploy.nix
  ./nixos/version.nix    # ← 追加
];
```

#### flake.nix の configurationRevision 設定

`version.nix` が参照する `system.configurationRevision` は flake.nix のノード定義で設定する:

```nix
"<project>-prod" = { name, nodes, pkgs, ... }: {
  # ... deployment, imports, etc.

  # flake の git rev を configurationRevision に埋め込む
  # self.rev: clean tree の場合のコミットハッシュ
  # self.dirtyRev: 未コミット変更がある場合のハッシュ (末尾に -dirty)
  # null: git 管理外 (通常発生しない)
  system.configurationRevision = self.rev or self.dirtyRev or null;
};
```

Self-Deploy の場合、EC2 上の `colmena apply-local` は checkout されたリポジトリの flake を評価するため、
`self.rev` はその時点の git HEAD のコミットハッシュになる。

### メモリバジェット例（2GB RAM）

| コンポーネント | 割り当て |
|----------------|----------|
| Database (innodb_buffer_pool) | 256 MB |
| Application | ~200 MB |
| nginx | ~10 MB |
| OS + nix-daemon | ~500 MB |
| nix-daemon MemoryMax | 1536 MB |
| Swap | 1 GB (safety net) |
