# Codex native hook policy

The current desktop/CLI model is GPT-6 Astra. Shell hooks do not have a reasoning
model: keep deterministic checks and useful context, rather than adding model
calls to every turn. Model/effort tuning is separate from this policy.

## Ownership and retained behavior

`modules/codex-hooks.nix` owns the system file `/etc/codex/hooks.json`. It retains:

| Event | Behavior | Limit |
| --- | --- | --- |
| SessionStart | Four shared Claude memory-index chunks | 3 seconds each; existing byte/line bounds |
| SessionStart | Existing world-model routing and conditional daily pending notice | 3 seconds each; original content and relevance rules |
| SessionStart / compact | Short resume reminder, without unavailable tools or plan-mode confirmation | 3 seconds |
| UserPromptSubmit | Existing three-project title/stub candidates | 8 seconds; original 5-second search deadline and candidate cap |
| PreToolUse / Bash | Existing synchronous Scrapbox append guard | 3 seconds; exit-2 denial unchanged |
| PostToolUse / legacy Gmail draft matcher | Existing draft audit helper | 3 seconds; target and matcher unchanged |

Codex normalizes shell tools to `Bash` for hooks. Preserve this guard: inspecting
only the raw shell tool name can incorrectly suggest that it is inactive. Hooks
are not a universal security boundary and do not cover every hosted tool path.
The Gmail helper remains a pre-existing personal dependency under
`~/.claude/scripts/gmail-draft-diff/`; do not claim it is supplied by this repo or
expand its matcher to other accounts without a separate review.

The shared scripts and Claude settings themselves are unchanged. Codex native
memory remains enabled as a separate supplemental layer; shared-memory writes
still use `self-learn` and the existing canonical store.

## Removed automatic behavior

The inspected legacy user hook copies are retired, not imported wholesale:
Claude-only Stop reconciliation/mandatory reflection/model-switch instructions,
`TaskList`/plan re-entry/compact-prep requirements, automatic init and terminal
rename, raw hook-payload logging, duplicate startup Nix sync, global SID checking,
and unsolicited CRM-choice prompting are no longer registered in Codex. Nix and
service checks remain available when the actual task calls their skills. CRM
implementation, its independent harness and Claude-only hooks are not changed.

The managed `notify` list is empty. Its former callback only performed automatic
LLM naming and overwrote task titles after each turn. Use native task naming and
`set_thread_title`; the manual `codex-name` CLI stays available unchanged. This is
not a blanket removal of notifications or plugin hooks. In particular, the enabled
Chrome plugin's native Stop cleanup remains owned by the distributed plugin.

## Reversible migration and order

Only exact, inspected SHA-256 legacy copies are adopted. Unknown content and
symlinks are not modified. Archives are kept under
`~/.local/state/home-manager-adoption/` with private directory/file permissions;
an unexpected archive collision fails closed. Hook trust state is not edited.

Home Manager activation precedes the system switch in `agent-config-apply`.
Therefore the old user hook file must remain until the live system hook file is
byte-identical to the desired registry. First apply installs that registry; a
second idempotent apply can archive the old file without a gap in the synchronous
safety guard. Temporary duplication is preferable to losing the guard. Verify the
archive hash and absence of the old discovery file after the second apply.

The inspected home-root AGENTS shadow is archived separately. It duplicated the
managed instructions and contained mechanically renamed, invalid routing paths.
Unknown project AGENTS files are not changed; the useful handoff and high-impact independent-validation contracts are kept
in the managed Codex prompt.

## Verification

Render the system registry and Home Manager activation snippets from the same
reviewed upstream input. Run `tests/codex-hook-policy-test.py --hooks <registry>`;
optional adoption flags take private fixture paths outside Git and exercise only
temporary HOME directories. Verify known-content migration, idempotence, unknown
content, symlinks, collision refusal, permissions and the system-readiness gate.
Check helper output using synthetic context/pending fixtures, with no network or
real user data. The actual legacy guard's rejection is independent evidence;
fixture assertions must not be described as a complete security guarantee.

After applying, reread `/etc/codex/hooks.json`, archives, AGENTS, model/effort,
`notify`, memory flags and plugin choices. Do not claim that a running task has
reloaded all hook definitions until a fresh lifecycle event is observed. Local
hook files do not automatically configure Web Work.

Official contracts: [Hooks](https://learn.chatgpt.com/docs/hooks),
[notify](https://learn.chatgpt.com/docs/config-file/config-advanced#notifications),
[Astra prompting](https://developers.openai.com/api/docs/guides/latest-model).
