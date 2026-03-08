# plural-reality/nix-darwin

macOS (nix-darwin + Home Manager) の共有インフラ flake。
個人設定を持たず、下流 flake が `lib.mkSystem` で自分の環境を構成する。

## Flake Outputs

```
lib.mkSystem                              — darwinSystem ビルダー (base + claude-code + shared-scripts + kimi-cli 全部入り)
packages.<system>.setup-downstream        — 対話式セットアップ (age鍵生成, sops暗号化, flake雛形)
packages.<system>.test-setup-downstream   — setup-downstream の自動テスト
packages.<system>.apply                   — apply スクリプト (flake update + darwin-rebuild switch)
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
3. `./apply` を実行 (shim: `nix run .#apply` → upstream の `packages.apply` を実行)

### 下流 flake の構造

```nix
{
  inputs.nix-darwin-upstream.url = "github:plural-reality/nix-darwin";
  outputs = { nix-darwin-upstream, ... }:
    let system = "aarch64-darwin"; in
    {
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

      apps.${system}.apply = {
        type = "app";
        program = "${nix-darwin-upstream.packages.${system}.apply}/bin/apply";
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

### マイグレーション (既存ダウンストリーム向け)

upstream が更新された際、ダウンストリームの `flake.nix` や `apply` shim を最新の構造に自動変換するマイグレーション基盤がある。

```bash
# マイグレーションのみ実行
nix run github:plural-reality/nix-darwin#migrate

# apply はマイグレーション + flake update + darwin-rebuild switch を一括実行
./apply
```

`./apply` は内部で `migrate` を呼んでいるため、通常は `./apply` だけで十分。
マイグレーションは冪等（適用済みのものはスキップされる）。

現在のマイグレーション:

| ID | 内容 |
|---|---|
| 001 | `mkSystem` → `mkDownstreamFlake` への flake.nix 変換 + `.envrc` 生成 |
| 002 | `./apply` shim を `github:` 直接参照に切り替え（ローカル lock 依存の解消） |

## 運用ガイド

### チームの最新状態に追いつく

どこにいても、これだけ打てばよい:

```bash
/private/etc/nix-darwin/apply
```

これ一発で以下が順に実行される:

1. `nix flake update` — upstream の最新リビジョンを取得
2. `migrate` — 破壊的変更があれば flake.nix / apply shim を自動変換（冪等）
3. `sudo darwin-rebuild switch --flake .` — システム再構築

shim 内部で `cd "$(dirname "$0")"` するため、カレントディレクトリに依存しない。

> 段階的に確認したい場合: `cd /private/etc/nix-darwin && nix flake update --commit-lock-file` → diff を見てから `darwin-rebuild switch --flake .`

### コントリビュート

#### 対象の切り分け

| 変更内容 | 変更先 |
|---|---|
| 全員に必要なツール・設定 | **このリポジトリ** (`modules/base.nix` 等) |
| 個人のツール・設定 | **自分の下流リポジトリ** (`personal.nix`) |
| AI プロンプト・スキル | **このリポジトリ** (`prompt/`, `modules/claude-code.nix`) |
| 新しい共有スクリプト | **このリポジトリ** (`scripts/`, `modules/shared-scripts.nix`) |

#### 開発フロー

```bash
# 1. clone & devShell に入る
git clone git@github.com:plural-reality/nix-darwin.git
cd nix-darwin
nix develop   # HLS, fourmolu, cabal-gild, nixfmt が使える

# 2. ブランチを切って変更
git checkout -b feat/add-something

# 3. フォーマット
nix fmt

# 4. セットアップスクリプトのテスト (下流 flake 生成の検証)
nix run .#test-setup-downstream

# 5. PR を出す
```

#### 変更時の注意

- **`mkSystem` / `mkDownstreamFlake` のインターフェースを変更する場合**: 既存の下流 flake が壊れないよう、`downstream/migrations/` にマイグレーションスクリプトを追加すること。
- **Nix**: `nix fmt` (nixfmt) で整形。
- **Haskell**: fourmolu で整形。言語拡張は `.hs` ではなく `.cabal` に記載。ビルドは cabal ではなく Nix (haskell-flake)。
- **Shell**: `set -euo pipefail` を先頭に。
- **ツール追加**: nixpkgs にあればそのまま使う。なければ GitHub 上の flake を input に追加。`brew install` / `pip install` 等のグローバルインストールは禁止。

## 内部構造

```
.
├── flake.nix                     — mkSystem 定義, perSystem (Haskell/screenpipe), outputs
├── modules/
│   ├── base.nix                  — programs (git, zsh, direnv, gh), env, PATH, macOS defaults
│   ├── claude-code.nix           — home.file: CLAUDE.md, GEMINI.md, settings.json, .cursorrules, skills (Claude/Codex)
│   └── shared-scripts.nix        — 11スクリプト定義 + home.packages
├── scripts/                      — Haskell/Python/Shell ソースコード
├── lib/
│   ├── expand-template.nix       — @[filename] 構文でテンプレート展開
│   └── expand-templates-dir.nix  — ディレクトリ内の全ファイルにテンプレート展開適用
├── prompt/                       — AI プロンプトテンプレート群
├── packages/screenpipe/          — screenpipe Nix ビルド定義
└── downstream/                   — 下流リポジトリ関連
    ├── setup.sh                  — 対話式セットアップスクリプト本体
    └── templates/                — setup で使う雛形
        ├── flake.nix.template    — 下流 flake.nix テンプレート (apps.apply 含む)
        └── apply                 — shim (nix run .#apply へ委譲)
```

### mkSystem が構成するもの (配管)

- Nix: flakes有効, trusted-users, linux-builder
- nixpkgs: unfree許可 (claude), hostPlatform
- ユーザー定義: users.users, primaryUser, shell=zsh
- Home Manager: useGlobalPkgs, useUserPackages, mac-app-util, sops-nix (secretsFile指定時)
- HM モジュール: base + claude-code + shared-scripts
- HM パッケージ: kimi-cli
- Homebrew: enable
- セキュリティ: Touch ID sudo, authorization defaults
