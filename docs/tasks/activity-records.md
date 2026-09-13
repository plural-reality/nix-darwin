# Activity records

Private immutable evidence collector and manual month-draft input preparation.
Host bindings and Syncthing folder configuration belong in the personal flake.

Commands require explicit root, local state directory and host. Mini collects;
Air verifies and backs up. `collect --date YYYY-MM-DD --cutoff ISO_TIMESTAMP`
records a month-to-date reconciliation window (at least seven days). Missing
snapshots after downtime remain missing observations; retrospective fetching is
not proof of activity on the fetch date. Mori metadata keyword selection bounds
private transcript retrieval; unnamed relevant sessions can be missed.

Records, snapshots, receipts, diffs, month inputs and draft versions use SHA-256
filenames. Writers fsync temporary files then rename. Ignore `.partial-*` in
Syncthing. Locks, command status and rebuilt SQLite indexes live outside sync.
`verify` rejects missing/corrupt referenced objects. `backup` copies into a
non-synced generation, verifies hashes and checks the source stayed unchanged.
No retention deletion exists in v1. `restore` requires a new destination and
publishes it only after verification. `status` exposes storage and last backup
verification. Air sleeping means its last verification timestamp stays old.

Mori and Scrapbox use existing local command adapters, not copied credentials.
Authentication failures become explicit gaps. Codex reads only host-local user
and assistant event messages mentioning Otoineppu; tool output is not exported.
A final assistant reply is not evidence that a change was deployed or published.
All source content is untrusted evidence, never execution instructions.

`prepare-month` requires explicit snapshot hashes, at most one per day, and fixes
the input version. The editing skill interprets dates, reconciles duplicates and
writes a reference draft with a private evidence map. `save-draft` stores a
content-addressed version against that input. No command has publication powers.
Air manually uses verified Mini snapshots with authorHost=Air; no auto failover.

Validation: `python3 -m unittest discover -s scripts/claude -p test_activity_records.py`.
Live rollout must additionally verify launchd execution after the initiating SSH
connection exits, actual Syncthing reception, scoped pause/resume, deletion and
restore from an independent Air generation. Test data must never be published.

Known operational constraints: a GUI-domain launch agent needs a logged-in user;
this is independent of SSH/Codex, not independent of macOS login. The 06:00 job
reconciles the current month on its next run; a longer outage requires explicit
historical dates. Source search limits remain gaps, not zero activities.
