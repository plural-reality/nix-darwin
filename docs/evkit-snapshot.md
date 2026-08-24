# `evkit snapshot` specification

## Calendar ledger and deletion

`evkit calendar.catalog` is the read-only calendar ledger. It returns every
EventKit event calendar with its stable calendar ID, display name, source
(`id`, `name`, `type`), `writable` flag, event count, observed date range, and
up to five representative titles. It does not accept a selector and never
silently narrows the result to configured names.

`evkit calendar.delete` is a typed, ID-keyed destructive operation. Its spec
must repeat the expected name, source identity/type, and `expectedEventCount: 0`:

```json
{
  "id": "...",
  "expectedName": "Business",
  "expectedSourceID": "...",
  "expectedSourceName": "iCloud",
  "expectedSourceType": 2,
  "expectedEventCount": 0
}
```

The signed bridge reads the calendar by ID, checks every precondition and
writability, verifies the calendar is empty across the 2000–2100 range, and
only then calls `removeCalendar`. A mismatch fails closed. Callers must read
the catalog again and verify the ID is absent after a successful response.

## Boundary

`evkit snapshot` is the single bulk-read operation for Apple Calendar and
Reminders. The existing signed `EventKitBridge.app` remains the only EventKit/TCC
boundary. The operation uses public EventKit APIs directly, adds no daemon,
cache, dependency, or fallback to `osascript`, `remindctl`, `icalBuddy`, or
`ekctl`.

`scripts/claude/lifelog.py` also uses this operation for its Apple Calendar
source. It passes the configured calendar names explicitly over stdin, requires
every configured name to resolve to at least one EventKit container, and treats
authorization, transport, malformed response, and missing-container outcomes as
typed source failures. The adapter never launches or scripts Calendar.app.

`status` only reads the current authorization state. `seed` is the only
operation allowed to request authorization. Every other operation returns a
machine-readable error immediately for a source without full access.

## Input

The client accepts one JSON object on stdin:

```json
{
  "rangeStart": "2026-07-31T00:00:00+09:00",
  "rangeEnd": "2026-08-01T00:00:00+09:00",
  "calendars": {
    "names": ["Taka の予定", "Business"],
    "ids": []
  },
  "reminderLists": {
    "names": ["直近でやること"],
    "ids": []
  },
  "includeCompleted": false,
  "dueBefore": "2026-08-01T00:00:00+09:00"
}
```

- `rangeStart` is inclusive and `rangeEnd` is exclusive. Both are required,
  must be ISO 8601 instants, and `rangeStart < rangeEnd`.
- Container names and IDs are exact-match selectors. An empty selector selects
  no container; selecting every visible container is never implicit.
- `includeCompleted` defaults to `false`.
- `dueBefore` is optional and inclusive. When present, reminders with no due
  date remain included; dated reminders after it are excluded.
- Personal-calendar policy is outermost-caller configuration, not bridge code.
  For this MacBook Air the caller passes: `Taka の予定`,
  `takagi@plural-reality.com`, `Shunsuke Takagi (General)`, `Business `
  (末尾空白を含む),
  `ルーティーン`, `Intervals.icu`, `日本の祝日`. Shared calendars are not
  passed.
- Exact duplicate names can resolve to multiple containers (currently
  `日本の祝日`). The lifelog adapter de-duplicates identical event projections
  after the bridge has restricted the read to the explicit name selector; it
  never broadens the selector to every visible calendar.

## Output

The response is sorted-key JSON. Event rows are explicitly sorted by start,
end, calendar ID, then event ID. Reminder rows are sorted by due date (dated
first), list ID, title, then reminder ID. All dates are ISO 8601 instants.

```json
{
  "ok": true,
  "op": "snapshot",
  "partial": false,
  "status": {
    "event": {"raw": 3, "name": "fullAccess"},
    "reminder": {"raw": 3, "name": "fullAccess"}
  },
  "events": [{
    "id": "...", "title": "...", "start": "...", "end": "...",
    "allDay": false, "location": "...", "timeZone": "Asia/Tokyo",
    "calendar": {"name": "...", "id": "..."},
    "source": {"name": "iCloud", "id": "...", "type": 2}
  }],
  "reminders": [{
    "id": "...", "title": "...", "due": "...", "completed": false,
    "completedAt": null, "list": {"name": "...", "id": "..."},
    "priority": 0, "recurrence": [], "locationAlerts": []
  }],
  "containers": {"calendars": [], "reminderLists": []},
  "errors": {"events": null, "reminders": null}
}
```

If exactly one source fails, the authorized source is still returned with
`partial: true`, `ok: false`, and a source-local object under `errors`. If both
fail, both result arrays are empty. No authorization prompt or alternate reader
is attempted.

## Acceptance criteria

- Synthetic checks cover all-day and cross-midnight events, recurring
  occurrences/rules, time zones, overdue and undated reminders, location
  alarms, one-source failure, no-authorization immediate failure, explicit
  sorting, and exact container restriction.
- Event reads use the finite EventKit range predicate. Reminder reads are
  restricted to the explicitly selected lists; the in-memory `dueBefore`
  filter retains undated reminders, which EventKit's due-date predicates omit.
- The current Swift source compiles, its self-contained test executable passes,
  Nix build/test and `nix flake check` are run, and the active downstream build
  is verified before activation.
- After rebuilding/signing the same `EventKitBridge.app`, `evkit status` still
  reports both TCC statuses and requests no authorization. A live
  `evkit snapshot` is compared with Calendar/Reminders readback for
  2026-07-31, returns incomplete reminders, and is measured repeatedly with a
  p95 target below one second.
