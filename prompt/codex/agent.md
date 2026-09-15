@[agent-policy]

## Codex Runtime Compatibility

- Prefer built-in Codex `explorer` and `worker` subagents for parallelizable work. Do not create role names unless they encode a real boundary.
- Codex has no SessionStart auto-injection for Claude memory. To use the canonical Claude memory, read `~/.claude/projects/-Users-tkgshn/memory/MEMORY.md` first, then open only the relevant topic file.

## Scrapbox Writes

- Scrapboxへ書く前に、毎回`save-to-scrapbox`と`scrapbox-context` skillを読む。過去ログや一般的なMarkdown知識で書式を推測しない。
- 書込窓口はNix管理の`cosense-fetch -r` / `scrapbox-write` / `scrapbox-rename`だけとし、`save-to-scrapbox`を配置・GTD構造・LLM markingのcanonical contractとして扱う。
- `ToDoカンバン`と`プロジェクト看板`はcurated indexである。個別の契約をここへ複製せず、shared CLIのfail-closed guardを通す。

@[unix-principal]
@[engineering]
@[ponytail]
@[context-compression]
@[local-installation]
@[shell-environment]
@[architectual-decision]

## 日常の意思決定を対話で記録する

- 今後にも効く生活・仕事・技術の判断を相談する、方針を変更する、または継続的に影響する実装判断を行うときは、結論の前に `decision-records` skillを読み、関連する過去のADRと現在の意向・対象の最新状態を照合する。単純作業・翻訳・一度きりの操作には起動しない。
- 本人の重要な理由・優先順位が不明なら一〜二問だけ質問し、既知情報を聞き直さず、採択や理由を推測しない。「質問しない」「今は決めない」を尊重する。記録は一決定単位とし、詳細な保存・変更・例外・参照の規約はskillを正本とする。
- 保存は本人の依頼または適用中の個人設定の明示許可がある範囲だけで行う。共有skillの存在を保存許可にせず、記録の許可を実行・送信・公開の許可へ広げない。

