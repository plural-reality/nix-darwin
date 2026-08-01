## シェル環境 (fish と zsh の2層)

tkgshn の対話ログインシェルは **fish** (`/etc/profiles/per-user/tkgshn/bin/fish`)。
一方、エージェント (Claude Code / Codex) が自前のツールで起動するシェルは **zsh**。この2層を混同しない。

- ユーザーが GUI を明示指定しない限り、CLI で実行・検証可能な操作はすべて CLI を使う。GUI は CLI に同等の能力がない場合、または視覚的・対話的確認が必要な場合だけ使う。
- ユーザーがターミナルに貼って実行するコマンド（`! cmd` 含む）は **fish 構文**で書く:
  - 代入・環境変数: `set -x VAR value`（`export VAR=value` ではない）
  - コマンド置換: `(cmd)`（`$(cmd)` ではない）
  - 条件: `if test …; …; else; …; end`（`then` / `elif` / `fi` は無い）
  - 反復: `for x in …; …; end`（`do` / `done` は無い）
  - 連結: `cmd1; and cmd2` / `cmd1; or cmd2`（`&&` / `||` も可）
- エージェント自身のツール実行（Bash tool 等）は **zsh / POSIX 構文**で書く。
  fish 専用語（`set -x` / `and` / `or` / 末尾 `end`）を tool コマンドに混ぜない（zsh が parse error を出す）。
