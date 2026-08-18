# iMessage history CLI

## Decision

General iMessage transcript history has no public macOS API. The Messages
framework supports iMessage extensions and composition, while Messages.app's
Apple Event dictionary exposes chats and send operations but not a transcript
history collection. The local `~/Library/Messages/chat.db` adapter is therefore
unsupported and protected by Full Disk Access.

Do not grant Full Disk Access to Terminal, Codex, Python, or a generic MCP host.
Use a separately named and signed `MessageHistoryBridge.app` with a fixed query
algebra.

```text
JSON request
  -> imsg-history
  -> mode-0600 launchd Unix socket
  -> MessageHistoryBridge.app/message-historyd
  -> SQLite OPEN_READONLY + query_only
  -> JSONL records + terminal end record
```

Calendar/Reminders remain in `EventKitBridge.app`. The two boundaries are not
merged: they use different frameworks, permissions, data sensitivity, and
contracts.

## Threat model

The socket mode excludes other users, not other processes running as the same
UID. Enabling this service deliberately allows same-UID processes to make the
fixed read-only history queries exposed by the bridge. This is narrower than
Full Disk Access for the agent runtime, which would also expose Mail, Safari,
Home, backups, and other protected data.

The bridge does not expose:

- arbitrary SQL or database path input;
- send, edit, delete, watch, or attachment-open operations;
- attachment filesystem paths;
- AppleScript, shell, or JavaScript evaluation.

The request limit is 1 through 1000 and the request line is bounded at 16 KiB.
Older pages remain reachable through the `(dateRaw, rowID, chatRowID)` cursor
returned in `nextCursor`. The typedstream decoder is bounded at 8 MiB and reports
`typedstream_heuristic` or `unsupported`; it does not claim a complete archive
decode.

The builder reuses the user's existing valid Apple Development identity. A
live probe confirmed that `/usr/bin/codesign` can use it unattended, matching
the user's explicit 2026-08-01 **Always Allow** decision; the bridge does not
create or import another private key. Another same-UID process can therefore
sign an arbitrary replacement with that identity and may inherit the bridge's
TCC grant. Fixed bridge queries remain the normal interface, but the signing
ACL is not a defense against a hostile same-UID process.

## Storage correctness

- Short reads query the live database through `SQLITE_OPEN_READONLY |
  SQLITE_OPEN_NOMUTEX`, `PRAGMA query_only=ON`, and
  `sqlite3_db_readonly(...)=1`.
- Full-text search first uses the SQLite Online Backup API to create a private
  ephemeral snapshot, closes the live source, scans the snapshot, and deletes
  it on process exit.
- `immutable=1` is never used for the live database. It is an assertion, not a
  snapshot mechanism.
- Conversation membership is derived from `chat_message_join`; participants
  come from `chat_handle_join`. `message.handle_id` is only the sender and can
  be `NULL` for outgoing/group messages.
- A message with multiple chat memberships produces one record per membership.
  Membership is not collapsed to an arbitrary chat.
- Output contains both the raw Apple timestamp and RFC 3339 UTC. Consumers own
  local-time presentation.

References: [Apple Full Disk Access](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/26/mac/26),
[Apple Messages framework](https://developer.apple.com/documentation/messages),
[SQLite Online Backup API](https://www.sqlite.org/backup.html), and
[SQLite URI parameters](https://www.sqlite.org/uri.html).

## Interface

```bash
imsg-history status
imsg-history recent 20
imsg-history search "query" 40
imsg-history chats "display name or handle" 40
imsg-history with "+8190..." 60   # direct thread only
imsg-history chat "iMessage;+;..." 60
```

The storage-independent form is JSON on stdin:

```bash
printf '%s\n' '{"op":"recent","spec":{"limit":20}}' | imsg-history request
printf '%s\n' '{"op":"recent","spec":{"limit":20,"before":{"dateRaw":1000000000000000000,"rowID":123,"chatRowID":4}}}' | imsg-history request
```

Every response is JSONL and ends with one terminal record. The CLI exits nonzero
unless the terminal record is successful.

```json
{"type":"message","message":{"rowID":1,"guid":"...","dateRaw":1,"date":"...","direction":"them","sender":"...","service":"iMessage","chatRowID":4,"chatGUID":"...","chatName":null,"participants":["..."],"text":"...","decodeStatus":"legacy","attachmentCount":0}}
{"type":"end","ok":true,"count":1,"nextCursor":{"dateRaw":1,"rowID":1,"chatRowID":4}}
```

## Personal Nix binding

The shared repository owns the client, bridge source, tests, and protocol. The
downstream personal configuration is the single canonical binding for the local
source path, bundle identifier, signing identity, SQLite header, LaunchAgent,
and socket path. It also creates both runtime parent directories declaratively.
The LaunchAgent is a nix-darwin user agent whose `ProgramArguments[0]` is the
signed app executable itself. Do not route this TCC boundary through a shell,
Nix wrapper, or Home Manager launchd agent: Home Manager inserts `/bin/sh` and
`wait4path`, which makes the shell the responsible process for Full Disk Access.
The app path is activation-time state outside `/nix/store`, so no store wait is
required.

The runtime socket name in `IMSG_HISTORY_SOCKET` must match the binding. The
default is `.../MessageHistoryBridge/message-historyd.sock`; override it only in
the personal Nix binding.

## Activation boundary

1. Build the Nix configuration and bridge tests.
2. Apply the downstream configuration. This installs the client, builder,
   direct-exec LaunchAgent, directories, and mode-0600 socket without foreground
   UI.
3. Run `imsg-history-build`. The declarative personal binding explicitly
   selects the existing unattended Apple Development identity, creates an
   immutable signed generation, and moves the `current` symlink.
4. Manually add `MessageHistoryBridge.app` to System Settings > Privacy &
   Security > Full Disk Access. macOS does not permit code to self-grant this.
5. Reload the per-user LaunchAgent through the Nix switch. Do not invoke the app
   from a shell when testing FDA; send the request through the socket.
6. Verify the signature, designated requirement, socket mode, `imsg-history
   status`, synthetic tests, and a minimal live/UI comparison that does not log
   private message text.

Building is not activation, and activation without the final live readback is
not completion.

Step 3 is the one that rots. The signing certificate expires, `build.sh` then
refuses to sign, and the daemon keeps serving the previously signed binary —
which still runs, because an expired certificate does not stop already-signed
code. Nothing reports it until someone next builds. That is how a certificate
that expired on 2026-08-03 went unnoticed until 2026-08-18, when a fix to the
bridge was applied to the source but never reached the running daemon.

`scripts/claude/signed-bridge-check.sh` surfaces this at Claude Code session
start. It reads each deployed bridge's own signature to find the certificate
that signed it, so it needs no copy of the identity configured downstream, and
it stays silent unless a certificate is expired, expiring within 30 days, or
missing. Renewing the certificate is a human step; rerun `imsg-history-build`
afterwards, then read back through the socket.
