## 言語

常に日本語で返答してください。コード・コミットメッセージ・識別子・ログなど、技術的に英語が適切なものは英語のままで構いません。

常に、並行でこなせる作業は、チームを組んで最大効率で作業してください。

## Routing Table

| Context | Reference |
|---------|-----------|
| Project-specific context | Each repo's `AGENTS.md`; if only `CLAUDE.md` exists, treat it as the compatibility source |
| 人脈活用・紹介依頼・相談メッセージ | `ask-network` skill |
| 返信の収集・統合・元の相手への返信作成 | `collect-and-reply` skill |

## 外部メッセージの下書き確認

- エージェントが本文を生成・編集したメール、Beeper、iMessage、DMその他の人への外部メッセージは、必ず二段階で送る。最初のターンでは送信先（相手・チャネル・返信先）と送信する本文全文を提示して停止し、その**後のユーザー発言**で未変更の下書きへの明示承認を得てから送信する。
- 本文を提示する前の「送って」「返信して」は、内容の作成依頼であって、生成された下書きの承認ではない。同じターンで起草から送信まで進めない。CLIの `--ack`、ツール実行許可、一般的な継続許可も本文承認の代わりにしない。
- 承認後に送信先、返信先、件名、本文のいずれかを変えた場合は、変更後の全文を再提示して再承認を得る。ユーザーが本文を逐語的に指定し「このまま送って」と依頼した場合だけ、その発言自体を本文承認としてよい。

## Agent Compatibility

- `AGENTS.md` is the Codex-native repo rule file. `CLAUDE.md` is the Claude Code-native repo rule file. Either is a compatibility input when the other does not exist.
- Claude-specific commands, permission syntax, and `.claude/agents` definitions are not Codex settings. Codex-specific sandbox policies, plugins, and subagents are not Claude settings. Translate only the semantic contract.

## Shared Agent Skills And Memory

- Managed shared skills live only in `~/Developer/plural-reality/nix-darwin/prompt/claude-code/skills/<name>/`. Home Manager projects that canonical source into both `~/.claude/skills` and `~/.codex/skills`; do not copy skill contents between runtime directories.
- Claude's self-learning memory canonical store is the harness-native auto-memory under `~/.claude/projects/<project>/memory/`. `~/.codex/memories` is Codex's own store, not Claude's.
- Use the `self-learn` skill for Claude memory writes. Never route Claude memory into `~/.codex/memories`.

## Codex / Claude Code Collaboration

- Codex is the execution system: implementation, test fixes, CI/log triage, parallel investigation, mechanical changes, and review worktrees.
- Claude Code is the planning, reasoning, and review system: specification clarification, design consultation, UI/copy alternatives, and fresh-context adversarial review.
- Do not let the same context both implement and approve. Hand implementation to the other agent for correctness, regressions, and stated-requirements review.
- Completion is proven by command output or visual verification, never an LLM self-report.
- If external consultation or another agent is a bottleneck, use local inspection and parallel subagent review first.

## Agent Handoff Protocol

When handing work between Claude Code and Codex, create a paste-ready handoff instead of forwarding chat fragments. Include `cwd`, `goal`, `non-goals`, `repo rules`, `current state`, `target files`, `commands run`, `acceptance criteria`, `verification`, and `open questions`.

For substantial work, keep that handoff in a repo-local `TASK.md`, `PLAN.md`, or issue body as the single context stream.

## Browser Verification

- For visual or interactive verification, use the installed Google Chrome profile.
- Do not use a bundled browser unless the user explicitly asks for an isolated browser.
- If Playwright is unavoidable, use the real Chrome channel (`--browser chrome`).

## スケジュール・空き時間の確認

- 本人の予定や空き時間を見るとき（「いつ空いてる?」「日程入れて」等）は、**Apple Calendar を必ず読む**。Google Calendar だけだとほぼ空に見えるが、予定の実体は Apple/iCloud 側にある。
- 本人の予定は Apple Calendar の **「☑️ チェック付き」カレンダーだけ**: `Taka の予定` / `takagi@plural-reality.com` / `Shunsuke Takagi (General)` / `Business` / `ルーティーン` / `Intervals.icu`(トレーニング計画=可動) / `日本の祝日`。チェックの無い `Univ` / `勤務先` / `Personal` / `Exercise` / `惟の居住地` / `目黒区民プール` / `Yui` / `Ryu` 等は **共有=他人の予定**なので空き判定から除外する。
- 読取りは osascript で全カレンダーを日付範囲フィルタ → 上記リストの `name of cal` だけ残す。書込みは `apple-calendar` skill（iCloud固定・位置情報つき・時刻指定）を唯一の窓口にし、直接 osascript で作らない。
