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

      # 便利: nix run .#deploy (build → cachix push → colmena apply)
      apps.aarch64-darwin.deploy = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy" ''
          set -euo pipefail

          echo "=== Building NixOS closure ==="
          RESULT=$(nix build .#colmenaHive.nodes.<project>-<env>.config.system.build.toplevel --print-out-paths --no-link)

          echo "=== Pushing to Cachix ==="
          export CACHIX_AUTH_TOKEN=$(${pkgs.sops}/bin/sops -d secrets/ci.yaml | ${pkgs.yq-go}/bin/yq '.cachix_auth_token')
          echo "$RESULT" | ${pkgs.cachix}/bin/cachix push <project>

          echo "=== Deploying via Colmena ==="
          time ${colmena.packages.aarch64-darwin.colmena}/bin/colmena apply \
            --impure --on <project>-<env> "$@"
        ''}";
      };

      # フォールバック: Cachix 障害時に SSH 直接転送でデプロイ
      apps.aarch64-darwin.deploy-ssh = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in "${pkgs.writeShellScript "deploy-ssh" ''
          set -euo pipefail
          echo "Deploying <project-name> via SSH (fallback)..."
          time ${colmena.packages.aarch64-darwin.colmena}/bin/colmena apply \
            --impure --on <project>-<env> "$@"
        ''}";
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
EC2 は Cachix substituter から pre-built closure を pull するため、実質的なビルド負荷はゼロ。
`buildOnTarget` は `colmena apply`（リモートデプロイ / フォールバック）時のみ関係する。

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

      # EC2 が Cachix + cache.nixos.org から直接パッケージを取得
      # → SSH 転送不要。ローカルで cachix push した closure を EC2 が pull
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

### メモリバジェット例（2GB RAM）

| コンポーネント | 割り当て |
|----------------|----------|
| Database (innodb_buffer_pool) | 256 MB |
| Application | ~200 MB |
| nginx | ~10 MB |
| OS + nix-daemon | ~500 MB |
| nix-daemon MemoryMax | 1536 MB |
| Swap | 1 GB (safety net) |
