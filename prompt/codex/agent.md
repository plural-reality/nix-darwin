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
