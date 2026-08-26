## 言語

常に日本語で返答してください。コード・コミットメッセージ・識別子・ログなど、技術的に英語が適切なものは英語のままで構いません。

## Codexタスク名

- タスク名は一覧用の派生表示であり、進捗・確認要否・完了根拠の正本ではない。
- 状態は `⬜` / `⌛️` / `☑️` / `⏹️` と、本人の対応を求める `🚨` を使う。`⏳` はCodexタスク名に使わない。
- エージェントが次の作業を進められる時だけ `⌛️ {主題}`。本人の判断・認証・確認・操作がなければ進められない時は `🚨 {主題}` にし、何をすればよいかを主題へ短く添える。外部応答待ちは `⌛️ {主題}（{相手}の返信待ち）` と明記し、停止理由を隠さない。正本を再読込して保留がなくなった時だけ `☑️ {主題}`。ユーザーが明示的に止めた時だけ `⏹️ {主題}`。未着手として残す時だけ `⬜ {主題}`。
- 状態変更だけでは主題を変えない。Codex Desktopでは状態遷移時に `set_thread_title` を使い、タイトルを更新する。

独立した read-heavy subtask が2つ以上あり、並列化が実時間を短縮する場合だけチームを組んでください。小さい作業、write-heavy作業、単一境界の作業は単独で実行し、subagentには原則 `fork_turns="none"` で必要な文脈だけ渡してください。親は各 child の terminal / interrupted / unsupported、evidence pointer、未解決事項を含む terminal manifest を記録してから「全部完了」と判断し、nested fan-out はしません。

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

## Shared Agent Skills And Memory

- Managed shared skills live only in `~/Developer/plural-reality/nix-darwin/prompt/claude-code/skills/<name>/`. Home Manager projects that canonical source into both `~/.claude/skills` and `~/.codex/skills`; do not copy skill contents between runtime directories.
- Claude's self-learning memory canonical store is the harness-native auto-memory under `~/.claude/projects/<project>/memory/` (home/personal agent context = `~/.claude/projects/-Users-tkgshn/memory/`). A Nix-managed Codex `SessionStart` hook injects its bounded `MEMORY.md` pointer index. For every non-trivial task, use that index and READ only the relevant `feedback_/reference_/project_*.md` topic file before answering or acting; re-read the canonical file before relying on drift-prone facts.
- WRITE: to add/update memory, use the `self-learn` skill against that store (one fact per file + one-line MEMORY.md pointer). Do NOT write to `~/.codex/memories` — Claude does not read it, so writes there never reach Claude.
- Codex native memory generation/use is disabled in managed config. `~/.codex/memories` may remain as historical runtime state, but it is NOT read or written as shared memory.

## Scrapbox Writes

- Scrapboxへ書く前に、毎回`save-to-scrapbox`と`scrapbox-context` skillを読む。過去ログや一般的なMarkdown知識で書式を推測しない。
- 書込窓口はNix管理の`cosense-fetch -r` / `scrapbox-write` / `scrapbox-rename`だけとし、`save-to-scrapbox`を配置・GTD構造・LLM markingのcanonical contractとして扱う。
- `ToDoカンバン`と`プロジェクト看板`はcurated indexである。個別の契約をここへ複製せず、shared CLIのfail-closed guardを通す。

## Browser Verification

- For visual or interactive verification, prefer the Codex Chrome plugin connected to the user's installed Google Chrome profile.
- Do not use the Codex in-app Browser or Playwright's default Chromium/Chrome for Testing unless the user explicitly asks for an isolated browser.
- If Playwright MCP is unavoidable, run it with the real Chrome channel (`--browser chrome`) rather than its bundled browser.

@[agent-operations]

## スケジュール・空き時間の確認

- 本人の予定や空き時間を見るとき（「いつ空いてる?」「日程入れて」等）は、**Apple Calendar を必ず読む**。Google Calendar だけだとほぼ空に見えるが、予定の実体は Apple/iCloud 側にある。
- 本人の予定は Apple Calendar の **「☑️ チェック付き」カレンダーだけ**: `Taka の予定` / `takagi@plural-reality.com` / `Shunsuke Takagi (General)` / `Business` / `ルーティーン` / `Intervals.icu`(トレーニング計画=可動) / `日本の祝日`。チェックの無い `Univ` / `勤務先` / `Personal` / `Exercise` / `惟の居住地` / `目黒区民プール` / `Yui` / `Ryu` 等は **共有=他人の予定**なので空き判定から除外する。
- 読取りは osascript で全カレンダーを日付範囲フィルタ → 上記リストの `name of cal` だけ残す。書込みは apple-calendar skill（iCloud固定・位置情報つき・時刻指定）を唯一の窓口にし、直接 osascript で作らない。

@[unix-principal]
@[engineering]
@[ponytail]
@[context-compression]
@[local-installation]
@[shell-environment]
@[architectual-decision]
@[coast-local]
