常に、並行でこなせる作業は、チームを組んで最大効率で作業してください。

## Routing Table

| Context | Reference |
|---------|-----------|
| Project-specific context | Each repo's `AGENTS.md`; if only `CLAUDE.md` exists, treat it as the compatibility source |
| 人脈活用・紹介依頼・相談メッセージ | `ask-network` skill |
| 返信の収集・統合・元の相手への返信作成 | `collect-and-reply` skill |

## Claude Code Compatibility

- `AGENTS.md` is the Codex-native repo rule file. `CLAUDE.md` is accepted as a compatibility input when the repo has not been migrated yet.
- Claude-specific commands, permission syntax, and `.claude/agents` definitions are not Codex settings. Translate them to Codex profiles, skills, plugins, or built-in subagents only when the semantics match.
- Prefer built-in Codex `explorer` and `worker` subagents for parallelizable work. Do not create role names unless they encode a real boundary.

## Browser Verification

- For visual or interactive verification, prefer the Codex Chrome plugin connected to the user's installed Google Chrome profile.
- Do not use the Codex in-app Browser or Playwright's default Chromium/Chrome for Testing unless the user explicitly asks for an isolated browser.
- If Playwright MCP is unavoidable, run it with the real Chrome channel (`--browser chrome`) rather than its bundled browser.

@[unix-principal]
@[engineering]
@[context-compression]
@[local-installation]
@[architectual-decision]
