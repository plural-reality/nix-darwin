## 言語

常に日本語で返答してください。コード・コミットメッセージ・識別子・ログなど、技術的に英語が適切なものは英語のままで構いません。

常に、並行でこなせる作業は、チームを組んで最大効率で作業してください。

## Routing Table

| Context | Reference |
|---------|-----------|
| Project-specific context | Each repo's `CLAUDE.md`; if only `AGENTS.md` exists, treat it as the compatibility source |
| 人脈活用・紹介依頼・相談メッセージ | `/ask-network` |
| 返信の収集・統合・元の相手への返信作成 | `/collect-and-reply` |

## Claude Code 履歴検索 (`ch`)

過去のセッションを探すときは `ch` コマンド（`~/.claude/scripts/claude-history.sh`）を使う。Claude Code に聞くより速い。

- `ch` — fzf でプロジェクト横断ファジー検索（386+ sessions indexed）
- `ch "keyword"` — プリフィルタ付き検索
- `ch --rebuild` — インデックス強制再構築
- `ch --list | grep X` — パイプ対応

選択すると `claude --resume <id>` がクリップボードにコピーされる。
インデックスは `~/.claude/.history-index.tsv` にキャッシュ（1時間で自動差分更新）。

## Codex Compatibility

- `CLAUDE.md` is the Claude Code-native repo rule file. `AGENTS.md` is accepted as a compatibility input when the repo has already migrated to Codex conventions.
- Codex approval policy, sandbox mode, plugins, and MCP entries are not Claude permission settings. Translate only the semantic contract, not the concrete file format.

## Browser Verification

- For visual or interactive verification, prefer Claude Code's Chrome extension/native host connected to the user's installed Google Chrome profile.
- Do not use Playwright's default Chromium/Chrome for Testing unless the user explicitly asks for an isolated browser.
- If Playwright MCP is unavoidable, run it with the real Chrome channel (`--browser chrome`) rather than its bundled browser.

@[unix-principal]
@[engineering]
@[context-compression]
@[local-installation]
@[architectual-decision]
