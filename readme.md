# plural-reality/nix-darwin

macOS (nix-darwin + Home Manager) の共有インフラ flake。
個人設定を持たず、下流 flake が `lib.mkSystem` で自分の環境を構成する。

## Flake Outputs

```
lib.mkSystem                              — darwinSystem ビルダー (base + claude-code + shared-scripts + kimi-cli 全部入り)
packages.<system>.setup-downstream        — 対話式セットアップ (age鍵生成, sops暗号化, flake雛形)
packages.<system>.test-setup-downstream   — setup-downstream の自動テスト
packages.<system>.screenpipe              — screenpipe ビルド
packages.<system>.{tar-map,url2content,lines2tar} — Haskell CLIツール (haskell-flake 由来)
formatter.<system>                        — nixfmt
devShells.<system>.default                — Haskell 開発環境 (HLS, fourmolu, cabal-gild)
```

## 使い方

### 新規セットアップ

```bash
nix run github:plural-reality/nix-darwin#setup-downstream
```

age 鍵の生成、secrets の暗号化、下流 flake の雛形生成を対話的に行う。
生成されるファイル: `flake.nix`, `secrets.yaml`, `.sops.yaml`, `.gitignore`, `apply`

### セットアップ後の流れ

1. `cd /private/etc/nix-darwin` (生成先ディレクトリ)
2. 必要なら `personal.nix` を作成（後述）
3. `./apply` を実行 (`nix flake update` → `darwin-rebuild switch --flake .`)

### 下流 flake の構造

```nix
{
  inputs.nix-darwin-upstream.url = "github:plural-reality/nix-darwin";
  outputs = { nix-darwin-upstream, ... }: {
    darwinConfigurations."My-Mac" = nix-darwin-upstream.lib.mkSystem {
      userConfig = {
        username = "alice";
        hostname = "My-Mac";
        gitName = "Alice";
        gitEmail = "alice@example.com";
      };
      secretsFile = ./secrets.yaml;
      modules = [ ./personal.nix ];
    };
  };
}
```

### `lib.mkSystem` のインターフェース

| 引数 | 型 | 必須 | 説明 |
|---|---|---|---|
| `userConfig` | `{ username, hostname, gitName, gitEmail }` | yes | ユーザー識別情報 |
| `secretsFile` | `path \| null` | no | sops secrets.yaml へのパス。null で SOPS 無効 |
| `modules` | `[module]` | no | darwin モジュール。追加/上書き用 |
| `system` | `string` | no | デフォルト `"aarch64-darwin"` |

mkSystem は base, claude-code, shared-scripts, kimi-cli を自動で含む。`modules` で追加/上書き:

```nix
modules = [
  ./personal.nix
  { homebrew.casks = [ "firefox" ]; }
  { nix.settings.max-jobs = 8; }
];
```

### personal.nix の書き方

`modules` は darwin module list に入る。HM オプションは `home-manager.users.${userConfig.username}` 経由:

```nix
# personal.nix
{ pkgs, userConfig, ... }:
{
  home-manager.users.${userConfig.username} = {
    home.packages = with pkgs; [ ripgrep fd jq ];
    programs.bat.enable = true;
  };

  homebrew.casks = [ "firefox" ];
}
```

`userConfig` は `mkSystem` が `specialArgs` に注入するため、どの module からも参照可能。

#### mkSystem の合成モデル

```
mkSystem { userConfig, secretsFile, modules }
│
├── plumbing (nix設定, ユーザー, homebrew, Touch ID)
│   └── HM (user identity + SOPS条件付き + base + claude-code + shared-scripts + kimi-cli)
└── ++ modules ← 下流が自由に拡張/上書き
```

## 内部構造

```
.
├── flake.nix                     — mkSystem 定義, perSystem (Haskell/screenpipe), outputs
├── modules/
│   ├── base.nix                  — programs (git, zsh, direnv, gh), env, PATH, macOS defaults
│   ├── claude-code.nix           — home.file: CLAUDE.md, GEMINI.md, settings.json, .cursorrules, skills
│   └── shared-scripts.nix        — 11スクリプト定義 + home.packages
├── scripts/                      — Haskell/Python/Shell ソースコード
├── lib/
│   ├── expand-template.nix       — @[filename] 構文でテンプレート展開
│   └── expand-templates-dir.nix  — ディレクトリ内の全ファイルにテンプレート展開適用
├── prompt/                       — AI プロンプトテンプレート群
├── packages/screenpipe/          — screenpipe Nix ビルド定義
├── templates/                    — setup で使う雛形
│   └── flake.nix.template        — 下流 flake.nix テンプレート
└── setup-downstream.sh           — 対話式セットアップスクリプト本体
```

### mkSystem が構成するもの (配管)

- Nix: flakes有効, trusted-users, linux-builder
- nixpkgs: unfree許可 (claude-code), hostPlatform
- ユーザー定義: users.users, primaryUser, shell=zsh
- Home Manager: useGlobalPkgs, useUserPackages, mac-app-util, sops-nix (secretsFile指定時)
- HM モジュール: base + claude-code + shared-scripts
- HM パッケージ: kimi-cli
- Homebrew: enable
- セキュリティ: Touch ID sudo, authorization defaults
