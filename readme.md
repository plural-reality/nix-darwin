# plural-reality/nix-darwin

macOS (nix-darwin + Home Manager) の共有インフラ flake。
個人設定を持たず、下流 flake が `lib.mkSystem` で自分の環境を構成する。

## Flake Outputs

```
lib.mkSystem              — darwinSystem ビルダー
modules.default           — base + claude-code + shared-scripts 全部入り (darwin-level)
modules.base              — git, zsh, direnv, gh, env, macOS defaults, 基本パッケージ
modules.claude-code       — CLAUDE.md, settings.json, .cursorrules, skills
modules.shared-scripts    — tar-map, url2content 等 11 スクリプト
homeManagerModules.*      — 上記と同内容の raw HM モジュール (mkSystem 外で使う場合)
packages.<system>.setup-downstream— 対話式セットアップ (age鍵生成, sops暗号化, flake雛形)
packages.<system>.test-setup-downstream— setup-downstream の自動テスト
packages.<system>.screenpipe      — screenpipe ビルド
apps.<system>.{tar-map,url2content,lines2tar} — Haskell CLIツール単体実行
devShells.<system>.default        — Haskell 開発環境 (HLS, fourmolu, cabal-gild)
```

## 使い方

### 新規セットアップ

```bash
nix run github:plural-reality/nix-darwin#setup-downstream
```

age 鍵の生成、secrets の暗号化、下流 flake の雛形生成を対話的に行う。
生成されるファイル: `flake.nix`, `secrets.yaml`, `.sops.yaml`, `.gitignore`, `apply`

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
      modules = with nix-darwin-upstream.modules; [
        default        # base + claude-code + shared-scripts
        ./personal.nix
      ];
    };
  };
}
```

### `lib.mkSystem` のインターフェース

| 引数 | 型 | 必須 | 説明 |
|---|---|---|---|
| `userConfig` | `{ username, hostname, gitName, gitEmail }` | yes | ユーザー識別情報 |
| `secretsFile` | `path \| null` | no | sops secrets.yaml へのパス。null で SOPS 無効 |
| `modules` | `[module]` | no | darwin モジュール。HM 設定もシステム設定も同一リストで渡す |
| `system` | `string` | no | デフォルト `"aarch64-darwin"` |

`modules` は darwin の module list に直接入る。override が普通のノリで書ける:

```nix
modules = with nix-darwin-upstream.modules; [
  default
  { homebrew.casks = [ "firefox" ]; }
  { nix.settings.max-jobs = 8; }
];
```

#### mkSystem の合成モデル

```
mkSystem { userConfig, secretsFile, modules }
│
├── plumbing (nix設定, ユーザー, homebrew, Touch ID)
│   └── home-manager integration (home.nix: user identity + SOPS条件付き)
└── ++ modules ← 下流が自由に拡張/上書き
```

すべてが同一の darwin module list にマージされるため、NixOS module system の通常の override セマンティクスがそのまま使える。

### `modules` vs `homeManagerModules`

| export | レベル | 用途 |
|---|---|---|
| `modules.*` | darwin | `mkSystem` と組み合わせて使う。HM modules を darwin レベルで wrap 済み |
| `homeManagerModules.*` | HM | `mkSystem` を使わず自前の darwinSystem で HM だけ組む場合 |

全部入り:
```nix
modules = [ nix-darwin-upstream.modules.default ];
```

個別選択:
```nix
modules = with nix-darwin-upstream.modules; [
  base
  shared-scripts
  # claude-code は除外
];
```

standalone (mkSystem 不使用):
```nix
home-manager.users.alice.imports = [
  inputs.nix-darwin-upstream.homeManagerModules.shared-scripts
];
```

`base` は `userConfig` を `specialArgs` で要求する。
`claude-code` と `shared-scripts` は `pkgs` と `lib` のみに依存し、追加引数不要。

## 内部構造

```
.
├── flake.nix                     — mkSystem 定義, perSystem (Haskell/screenpipe), outputs
├── home.nix                      — 最小 HM 基盤: user identity + SOPS条件付きインフラ
├── modules/
│   ├── base.nix                  — programs (git, zsh, direnv, gh), env, PATH, macOS defaults
│   ├── claude-code.nix           — home.file: CLAUDE.md, settings.json, .cursorrules, skills
│   └── shared-scripts.nix        — 11スクリプト定義 + home.packages
├── scripts/                      — Haskell/Python/Shell ソースコード
│   ├── tar-map.hs                — Tar Functor: stdin tar → コマンド適用 → stdout tar
│   ├── url2content.hs            — URL → Markdown 変換 (trafilatura経由)
│   ├── lines2tar.hs              — stdin行 → tarエントリ (パス名のみ、中身空)
│   ├── urls-under.py             — URL配下のリンクを再帰収集
│   ├── flatten-dir.py            — ディレクトリ構造の平坦化
│   ├── cat-all.py                — 全ファイル結合出力
│   ├── download-slack-channel-files.py
│   └── git-prompt.sh             — zsh git prompt
├── lib/
│   ├── expand-template.nix       — @[filename] 構文でテンプレート展開
│   └── expand-templates-dir.nix  — ディレクトリ内の全ファイルにテンプレート展開適用
├── prompt/                       — AI プロンプトテンプレート群
│   ├── antigravity.md            — Gemini GEMINI.md ソース
│   ├── claude-code/
│   │   ├── claude.md             — Claude Code CLAUDE.md ソース
│   │   └── skills/               — Claude Code skills (elm, haskell-flake, servant, colmena...)
│   └── cursor.md                 — Cursor .cursorrules ソース
├── packages/screenpipe/          — screenpipe Nix ビルド定義
├── templates/                    — setup で使う雛形
│   └── flake.nix.template        — 下流 flake.nix テンプレート
└── setup-downstream.sh           — 対話式セットアップスクリプト本体
```

### スクリプトパイプライン

共有スクリプトはストリーム指向で設計されている。stdin/stdout パイプで合成可能:

```
urls-under URL          → 行ストリーム (URL一覧)
lines2tar               → tar ストリーム (パス名をエントリ化)
tar-map --stdio CMD     → tar ストリーム (各エントリにCMD適用、Functor)
tar2dir DIR             → ファイルシステム (tar → ディレクトリ展開)
```

`save-site` はこれらを合成した例:

```bash
urls-under https://example.com | lines2tar | tar-map --stdio -- url2content | tar2dir ./out
```

### テンプレート展開 (`lib/expand-template.nix`)

プロンプトファイル内で `@[filename]` と書くと、`prompt/` ディレクトリ内の同名ファイルの内容に置換される。
`@[foo.md]` と `@[foo]` の両方が使える。
`expand-templates-dir.nix` はディレクトリ内の `SKILL.md` に対して同じ展開を一括適用する。

### `mkSystem` が構成するもの (配管のみ)

`mkSystem` は以下のインフラを自動設定する（下流が意識する必要なし）:

- Nix: flakes有効, trusted-users, linux-builder (cross-compile用)
- nixpkgs: unfree許可 (claude-code), hostPlatform
- ユーザー定義: users.users, primaryUser, shell=zsh
- Home Manager: useGlobalPkgs, useUserPackages, mac-app-util, sops-nix (secretsFile指定時)
- Homebrew: enable (casks は下流が modules で追加)
- セキュリティ: Touch ID sudo, authorization defaults
