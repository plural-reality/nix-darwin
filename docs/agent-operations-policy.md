# Agent operations policy

## Scope

This document is the design record for agent execution on a Mac that is also in
active use by its owner. It covers command routing, MCP boundaries, Chrome
workspace ownership, focus safety, and protected local application data.

The canonical runtime instruction is `prompt/agent-operations.md`. This document
explains the decisions; it does not duplicate the instruction text verbatim.

## Observed baseline

- Shared Claude Code and Codex instructions already have one source:
  `prompt/agent-operations.md`.
- The managed legacy browser projection exposes only the Chrome backend,
  disables the in-app browser and old pixel `computer-use@openai-bundled`
  plugin, and keeps the installed-Chrome plugin enabled. Global desktop input
  requires an explicit isolated VM/display or separately acquired desktop lease;
  this does not disable the separate, app-scoped Unified Computer Use route.
- The default Codex sandbox was `danger-full-access` even for work that only
  needs the current checkout.
- OneTab 2.18 is already installed in the relevant Chrome profiles. OneTab has
  no stable external automation contract, so its UI or extension storage cannot
  be a completion boundary.
- `mac-local-data` already documented an iMessage SQLite reader, but the current
  agent process cannot open `~/Library/Messages/chat.db`. Granting Full Disk
  Access to every changing agent runtime would be a broad and unstable TCC
  boundary.

## Two-week Codex audit

The local Codex record from 2026-07-19 through 2026-08-01 18:22:59 JST
contained 381 sessions (74 root, 307 subagent), 296,599 JSONL records, and
approximately 8.20 GiB. The audit's own parent task and subagents were excluded.
Private correspondence, finance, health, credentials, and oversized payloads
were excluded from content analysis.

The dominant avoidable cost was orchestration:

- 80.6% of sessions were subagents;
- 52 parents spawned 296 thread-style children;
- median fan-out was 4, p90 was 11, and the maximum was 41;
- root tasks made 1,921 coordination calls, 10.3% of all root tool calls;
- 6 of 10 review tasks did not complete, including four near-simultaneous jobs
  for one checkout which all failed to reach `task_complete`;
- root completion turns had p50 6m45s and p90 33m42s; 39.6% exceeded 10
  minutes and 12.3% exceeded 30 minutes;
- `Script failed` appeared 288 times across 110 sessions; timeouts and missing
  command/file probes each affected 11 sessions;
- 155 oversized JSONL records accounted for about 3.31 GB (3.08 GiB);
- stale Apple Events/window indices produced 31 strict GUI errors across 11
  sessions.

The positive baseline is also clear: 74.3% of root sessions contained strong
verification input, most often HTTP/canonical readback, visual readback, git
evidence, builds, and tests. Calls named `exec` or `exec_command` were
approximately 77.8% of all tool calls, although `exec` can also orchestrate
non-CLI operations. The correction is therefore not “more automation”; it is
less fan-out, idempotent task dispatch, smaller context, Result-typed probes,
and a fresh semantic snapshot before each unavoidable GUI action.

The enforced governor is:

- use subagents only for at least two independent read-heavy boundaries;
- at most three subagents, no nested spawn;
- root owns writes, GUI, and a single-repository change;
- deduplicate by `cwd + normalized objective + mode` before task/review creation;
- use one bounded wait rather than repeated polling;
- distinguish dispatched, completed, verified, deployed, and published states.

## Canonical execution model

Use the first boundary that can express and verify the operation:

1. Native CLI/API, including Chrome extension API or CDP.
2. A typed, pinned MCP projection.
3. A native accessibility API.
4. Pixel-based Computer Use.

This is a pipeline, not a list of equivalent adapters. Moving downward is
allowed only when the preceding boundary cannot express the operation or its
readback.

### Browser backend decision (2026-08-29)

The shared Mac is not an automation sandbox. The default route is the existing
Chrome extension/native host, whose tab IDs and turn-scoped cleanup are managed
by the Chrome plugin. The in-app browser is not a fallback: its backend is
removed from the runtime discovery allow-list, so an implicit default selection
cannot open a second browser surface. The old pixel Computer Use plugin is also
disabled by default because its mouse, keyboard, and focus events are global to
the desktop.

The separate Unified Computer Use route may perform necessary app-scoped native
work when its tools are exposed to the current task and the target app already
has permission. Prefer narrower CLI/API operations, avoid concurrent use of the
same app, and do not silently fall back from Chrome to desktop control. This is
not permission to expand app access or TCC, nor to weaken task-specific isolation
or lease requirements. New authentication and permission grants remain human
boundaries.

Only an explicitly isolated Playwright/Chrome for Testing run may create its own
profile, and that profile is run-scoped and disposable. A shared persistent
profile, fixed CDP port, copied user profile, or ad-hoc headless process is not
an isolation boundary. Existing user tabs and processes are never cleaned up by
the policy; ownership must come from the current connection and run, not from a
URL, PID, title, tab index, or last-focused window.

The scheduled GMO monitor is a concrete example of this boundary. Its former
`gmo-watch.mjs` path launched detached Google Chrome on a fixed CDP port and is
now fail-closed. It remains a status adapter for `daily-watch`, but it does not
start a browser until the monitor is moved to a dedicated VM/display or a
run-scoped lease broker. This deliberately trades one unattended check for
preventing a background job from hijacking the owner's Chrome session.

### Offline-first staging

Split network-dependent tasks into two phases:

1. Produce the complete transformation, fixtures, validation, and execution
   specification locally.
2. Run one narrow network phase and read the canonical result back.

Do not interleave code generation with repeated browser or network mutations.
The network phase must be restartable from an immutable input and must not use a
partially edited browser page as its only state.

## MCP boundary

Local MCP servers run with the client's authority. Therefore:

- execute a Nix-pinned program directly; do not add runtime `npx @latest` or an
  opaque shell startup command;
- prefer direct `stdio`; use a mode-0600 Unix socket only when a stable signed
  macOS process must own a TCC permission;
- expose typed, narrow tools instead of arbitrary shell, JavaScript, SQL,
  AppleScript, or accessibility mutation;
- keep stdout protocol-only and send logs to stderr;
- split reads from mutations and require target identifiers and idempotency
  keys for mutations;
- require an immediate target/input/side-effect preview, explicit authorization,
  and an audit record for mutation or sensitive-data retrieval; shell approval
  and filesystem sandbox settings do not authorize MCP/API side effects;
- grant Calendar, Messages, Automation, Accessibility, and Screen Recording to
  separate stable brokers only when the corresponding native boundary requires
  it. Do not grant those permissions to Terminal, Codex, or a generic MCP host.

An MCP wrapper is useful only when its schema or consent boundary is materially
safer than the existing CLI. Otherwise the CLI remains canonical.

## Execution isolation

The default Codex shell/filesystem write boundary is the current workspace.
Read-only research uses the read-only sandbox; an additional writable root is
injected explicitly for a task that needs it. `danger-full-access` is an
exception for a named local operation, not the ambient default. MCP, plugins,
Chrome, and external APIs remain separate capabilities with their own consent,
network, and data boundaries.

This filesystem sandbox does not prove focus safety. Focus safety is a separate
invariant: background work must not call application activation, send blind
keystrokes, or target the current/last-focused window.

Long-running work uses a per-user LaunchAgent only when it must outlive the
client. A short operation remains a foreground CLI pipeline or an on-demand
Unix-socket service. Root LaunchDaemons are not used for user application data.

## Chrome ownership and cleanup

Chrome is a shared exclusive resource. Every GUI run maintains an ownership set:

```text
run_id
browser_session_id / connection_epoch
owned_window_id
owned_tab_ids
created_at
```

The set contains only identifiers returned by creation calls in the same browser
connection epoch. URL, title, tab index, group membership, and the last-focused
window never prove ownership. Restart, disconnect, or reconnect invalidates the
set; stale identifiers are never used for cleanup.

- Create a project window with `focused: false` and tabs with `active: false`.
- Never call window/tab activation unless the user explicitly asks to see it.
- Close every agent-owned tab at the end of the operation. Close an agent-owned
  window when its ownership set becomes empty.
- Before cleanup, take a read-only snapshot of concurrent Codex/Claude sessions
  and their leases/owned sets. Do not close a tab, window, app, or process that
  another session or the user may own; clean only IDs created by this run in the
  same connection epoch.
- Relinquish ownership when the user activates or edits a tab, explicitly asks
  to see it, or accepts a handoff. Relinquished tabs are never auto-closed.
- Preserve all pre-existing tabs, groups, windows, downloads, form state, and
  browser history.
- Agent-created scratch data may be removed after canonical readback. Browser
  history is evidence for recovery, not permission to delete user-owned state.
- OneTab is a human-facing archive adapter. It may receive agent-owned tabs when
  requested, but its toolbar UI, internal DOM, and storage are not automated.
  User-owned tabs require a preview and explicit approval before OneTab or close.

If the available Chrome tool cannot create a background target or return stable
IDs, defer Chrome use to the final visual verification phase instead of
competing with the user for the active window.

Focus restoration is compare-and-swap only: restore when focus is still on the
same agent-owned window in the same epoch and no user action intervened.
Otherwise do nothing.

## Protected local application data

Apple exposes no public macOS API for general iMessage transcript history. The
Messages framework is for iMessage extensions and message composition, not an
arbitrary history query API. The local `chat.db` is therefore an unsupported
storage adapter and must be isolated behind a read-only boundary.

The intended boundary is a dedicated signed per-user Message History bridge:

```text
imsg-history CLI
  -> mode-0600 Unix socket
  -> stable signed MessageHistoryBridge.app
  -> SQLite query_only connection to ~/Library/Messages/chat.db
  -> JSONL stdout
```

The bridge accepts an allowlisted query algebra, never raw SQL. It returns text
and message metadata but does not open attachments or mutate the database. Full
Disk Access is granted manually to this one stable bundle identity. The bridge
must fail closed when access is absent; it must not open System Settings or
attempt to edit TCC state.

Launchd must execute the signed bridge binary directly. A shell, bootstrap
wrapper, or generic MCP host in the responsible-process chain changes the TCC
subject and invalidates the least-privilege boundary even when the app itself is
properly signed and listed under Full Disk Access.

This adds one structural security boundary. It does not add a second contract:
the CLI request/response schema is the only public interface, and any future MCP
tool is a mechanical projection of that schema.

## Completion evidence

An operation is complete only after the canonical surface is reread. Browser
tabs, notifications, screenshots, Coast history, task toasts, and process exit
alone are not proof of an external mutation.

## Change boundary and proof

The canonical policy and backend selection live in `modules/claude-code.nix`;
the runtime projection adapter is `scripts/merge-codex-config.py`; generated
`~/.codex`/`~/.claude` files are outputs and must not be edited directly. The
projection test must show that a stale `chrome,iab` runtime value becomes
`chrome`. Profiles use a complete fail-closed `node_repl` guard transport rather
than an env-only table, so selecting a profile cannot produce an invalid Codex
configuration before Desktop has written its runtime transport.
The narrow Nix proof is the `desktop-skills` build plus the Codex projection,
browser-isolation, and daily-watch static checks. Stopping the currently
orphaned headless processes is a separate human-approved cleanup operation,
not part of this source change.

The mutable `~/.claude/settings.local.json` override and physical helper files
are deliberately outside this projection. A raw CDP allow rule, an ad-hoc
headless helper, or the legacy profile-mtime SID refresh can therefore still
exist until an explicitly approved migration removes or replaces it. Nix
activation must not silently rewrite that user-owned state; live safety is
proven only after those paths have been audited and the generated links have
been reread.
