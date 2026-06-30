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

## Shared Agent Skills And Memory

- Managed shared skills live only in `~/Developer/plural-reality/nix-darwin/prompt/claude-code/skills/<name>/`. Home Manager projects that canonical source into both `~/.claude/skills` and `~/.codex/skills`; do not copy skill contents between runtime directories.
- Claude's self-learning memory canonical store = the harness-native auto-memory at `~/.claude/projects/<project>/memory/` (its `MEMORY.md` index is auto-injected every SessionStart). `~/.codex/memories` is Codex's own store, not Claude's.
- Memory routing and procedure are owned by the `self-learn` skill — do not restate store paths or steps here (single source of truth).
- To add/update Claude memory, use the `self-learn` skill (writes Store A + readback). Never hand-write `~/.codex/memories` for Claude memory.

## Codex / Claude Code 使い分け

- Codex は execution system として使う。repo 内実装、テスト修正、CI/log triage、並列調査、機械的変更、review worktree は Codex に渡す候補にする。
- Claude Code は planning/reasoning/review system として使う。設計相談、仕様の曖昧さの解消、UI/copy 候補比較、fresh-context adversarial review を優先する。
- 片方に作らせて同じ context で承認させない。Claude が実装したら Codex に review を渡し、Codex が実装したら Claude が correctness/regression/stated requirements を review する。
- 完了判定は LLM の自己申告ではなく、`nix build` / `npm test` / `npm run lint` / `xcodebuild` / screenshot verification などの command output を source of truth にする。
- 外部相談や別 agent 呼び出しが bottleneck になる場合は、local repo inspection と並列 subagent review を先に使い、Claude/Codex CLI 呼び出しは optional な補助手段として扱う。

## Codex CLI Handoff Protocol

Codex CLI に作業を引き継ぐときは、チャット断片を渡さない。必ず paste-ready な `Codex Handoff` を作り、次の項目を含める。

- `cwd`: 対象 repo の絶対パス。
- `goal`: 達成すべき状態を一文で書く。
- `non-goals`: 今回触らない境界を明示する。
- `repo rules`: 読むべき `AGENTS.md` / `CLAUDE.md` と、canonical source of truth。
- `current state`: 既に確認した事実、関連ファイル、既存の dirty changes。
- `target files`: 変更候補のファイル一覧。zsh glob を避けるため bracket path は quote する。
- `commands run`: 実行済み command と重要な結果。失敗も省略しない。
- `acceptance criteria`: 何が満たされれば完了か。
- `verification`: Codex 側で最後に実行すべき command。
- `open questions`: 人間判断が必要な点だけを残す。

Codex CLI への渡し方は、まず現在の `codex exec --help` を確認する。少なくともこの環境では read-only 調査なら `codex exec -c <cwd> --sandbox read-only '<prompt>'` が使える。実装を任せる場合は read-only ではなく、現在の Codex profile / approval policy に合う実行方法を選ぶ。

大きい作業では、handoff は一時チャットではなく repo-local `TASK.md` / `PLAN.md` / issue body に置く。ファイルを単一の context stream として扱い、Claude と Codex の間で仕様を重複定義しない。

## Browser Verification

- For visual or interactive verification, prefer Claude Code's Chrome extension/native host connected to the user's installed Google Chrome profile.
- Do not use Playwright's default Chromium/Chrome for Testing unless the user explicitly asks for an isolated browser.
- If Playwright MCP is unavoidable, run it with the real Chrome channel (`--browser chrome`) rather than its bundled browser.

@[unix-principal]
@[engineering]
@[ponytail]
@[context-compression]
@[local-installation]
@[shell-environment]
@[architectual-decision]
