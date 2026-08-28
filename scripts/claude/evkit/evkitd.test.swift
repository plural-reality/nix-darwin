import Foundation

@main
enum EventKitBridgeTests {
    static let date: (String) -> Date = { value in
        ISO8601DateFormatter().date(from: value)!
    }

    static let source = SnapshotSource(id: "source-1", name: "iCloud", type: 2)
    static let personal = SnapshotContainer(
        id: "calendar-personal", name: "Personal", source: source)
    static let shared = SnapshotContainer(
        id: "calendar-shared", name: "Shared", source: source)
    static let ledger = CalendarLedgerEntry(
        id: "calendar-empty", name: "Business", source: source, writable: true,
        eventCount: 0, firstEventStart: nil, lastEventEnd: nil,
        representativeTitles: [])

    static let events: [SnapshotEvent] = [
        SnapshotEvent(
            id: "recurring", title: "Recurring occurrence 2",
            start: date("2026-08-07T00:00:00Z"), end: date("2026-08-07T01:00:00Z"),
            allDay: false, location: nil, timeZone: "Asia/Tokyo",
            beeperCrmMessageId: nil,
            calendar: personal, source: source),
        SnapshotEvent(
            id: "all-day", title: "All day",
            start: date("2026-07-31T00:00:00Z"), end: date("2026-08-01T00:00:00Z"),
            allDay: true, location: nil, timeZone: "Asia/Tokyo",
            beeperCrmMessageId: nil,
            calendar: personal, source: source),
        SnapshotEvent(
            id: "cross-midnight", title: "Cross midnight",
            start: date("2026-07-31T14:00:00Z"), end: date("2026-07-31T17:00:00Z"),
            allDay: false, location: "Tokyo", timeZone: "Asia/Tokyo",
            beeperCrmMessageId: nil,
            calendar: personal, source: source),
        SnapshotEvent(
            id: "recurring", title: "Recurring occurrence 1",
            start: date("2026-07-31T00:00:00Z"), end: date("2026-07-31T01:00:00Z"),
            allDay: false, location: nil, timeZone: "Asia/Tokyo",
            beeperCrmMessageId: nil,
            calendar: personal, source: source),
    ]

    static let recurrence = SnapshotRecurrence(
        frequency: "weekly", interval: 1, firstDayOfWeek: 2,
        daysOfWeek: [SnapshotRecurrenceDay(day: 6, weekNumber: 0)],
        daysOfMonth: [], monthsOfYear: [], weeksOfYear: [], daysOfYear: [],
        setPositions: [],
        end: SnapshotRecurrenceEnd(date: nil, occurrenceCount: 12),
        calendarIdentifier: "gregorian")

    static let reminders: [SnapshotReminder] = [
        SnapshotReminder(
            id: "later", title: "Later", due: date("2026-08-02T00:00:00Z"),
            dueAllDay: false, dueTimeZone: "UTC", completed: false, completedAt: nil,
            list: personal, priority: 0, watchMarkers: [], recurrence: [], locationAlerts: []),
        SnapshotReminder(
            id: "undated", title: "Undated", due: nil, dueAllDay: false,
            dueTimeZone: nil, completed: false, completedAt: nil,
            list: personal, priority: 0, watchMarkers: [], recurrence: [], locationAlerts: []),
        SnapshotReminder(
            id: "overdue", title: "Overdue", due: date("2026-07-01T00:00:00Z"),
            dueAllDay: true, dueTimeZone: "Asia/Tokyo", completed: false,
            completedAt: nil, list: personal, priority: 1,
            watchMarkers: ["[watch:test]"],
            recurrence: [recurrence],
            locationAlerts: [SnapshotLocationAlert(
                title: "Office", latitude: 35.0, longitude: 139.0,
                radiusMeters: 250, proximity: "enter")]),
        SnapshotReminder(
            id: "completed", title: "Completed", due: nil, dueAllDay: false,
            dueTimeZone: nil, completed: true,
            completedAt: date("2026-07-30T00:00:00Z"), list: personal,
            priority: 0, watchMarkers: [], recurrence: [], locationAlerts: []),
    ]

    static let checks: [() -> Void] = [
        {
            let selected = selectContainers(
                [personal, shared],
                selectors: SnapshotSelectors(names: ["Personal"], ids: []))
            precondition(selected == [personal], "container selection must be exact and restricted")
        },
        {
            let selected = selectContainers(
                [personal, shared],
                selectors: SnapshotSelectors(names: [], ids: ["calendar-shared"]))
            precondition(selected == [shared], "container ID selection must work")
        },
        {
            precondition(
                selectContainers(
                    [personal, shared],
                    selectors: SnapshotSelectors(names: [], ids: [])).isEmpty,
                "empty selectors must never mean all containers")
        },
        {
            let sorted = sortEvents(events)
            precondition(sorted.map(\.title) == [
                "Recurring occurrence 1", "All day", "Cross midnight", "Recurring occurrence 2",
            ], "event occurrences, all-day, and cross-midnight rows must sort without deduplication")
            precondition(sorted[1].allDay && sorted[2].end > sorted[2].start)
            precondition(sorted[2].timeZone == "Asia/Tokyo")
        },
        {
            let filtered = filterReminders(
                reminders, includeCompleted: false,
                dueBefore: date("2026-08-01T00:00:00Z"))
            precondition(
                sortReminders(filtered).map(\.id) == ["overdue", "undated"],
                "overdue and undated reminders must remain; later/completed rows must not")
        },
        {
            let row = reminders[2]
            precondition(row.recurrence == [recurrence], "recurrence must remain structured")
            precondition(row.locationAlerts.first?.proximity == "enter")
            precondition(row.locationAlerts.first?.radiusMeters == 250)
        },
        {
            let full = AuthorizationState(raw: 3, name: "fullAccess")
            let denied = AuthorizationState(raw: 2, name: "denied")
            let partial = makeSnapshotResponse(
                eventStatus: denied, reminderStatus: full,
                eventResult: .failure(SourceFailure(
                    code: "authorization_denied", message: "events require full access")),
                reminderResult: .success([reminders[1]]),
                containers: SnapshotContainers(calendars: [], reminderLists: [personal]))
            precondition(!partial.ok && partial.partial)
            precondition(partial.events.isEmpty && partial.reminders.count == 1)
            precondition(partial.errors.events?.code == "authorization_denied")
        },
        {
            let denied = AuthorizationState(raw: 2, name: "denied")
            let error = fullAccessError(source: "events", status: denied)
            let unread: Result<[SnapshotEvent], SourceFailure> = readWhenAuthorized(
                status: denied, source: "events",
                reader: { preconditionFailure("unauthorized reader must not execute") })
            precondition(unread.snapshotError == error)
            let failed = makeSnapshotResponse(
                eventStatus: denied, reminderStatus: denied,
                eventResult: .failure(error!), reminderResult: .failure(error!),
                containers: SnapshotContainers(calendars: [], reminderLists: []))
            precondition(!failed.ok && !failed.partial)
            precondition(failed.events.isEmpty && failed.reminders.isEmpty)
        },
        {
            let request = CalendarDeleteRequest(
                id: "calendar-empty", expectedName: "Business",
                expectedSourceID: "source-1", expectedSourceName: "iCloud",
                expectedSourceType: 2, expectedEventCount: 0)
            precondition(calendarDeletionMatches(request, ledger))
            precondition(!calendarDeletionMatches(
                CalendarDeleteRequest(
                    id: "calendar-empty", expectedName: "Business",
                    expectedSourceID: "source-1", expectedSourceName: "iCloud",
                    expectedSourceType: 2, expectedEventCount: 1), ledger))
        },
        {
            precondition(
                beeperCrmMessageId("operator note\nbeeper-crm:msg:message-1")
                    == "message-1")
            precondition(beeperCrmMessageId("operator note") == nil)
            precondition(beeperCrmMessageId("beeper-crm:msg:") == nil)
        },
        {
            precondition(
                watchMarkers("private note\n[watch:corp-invoice-registration]\n[watch:corp-invoice-registration]")
                    == ["[watch:corp-invoice-registration]"])
            precondition(watchMarkers("[not-watch:private]").isEmpty)
            precondition(normalizedWatchMarker("[watch:ok]") == "[watch:ok]")
            precondition(normalizedWatchMarker("watch:bad") == nil)
        },
        {
            let data = Data("""
            {"listTitle":"多元タスク","title":"登録番号を請求書・freeeへ反映する","marker":"[watch:corp-invoice-registration]"}
            """.utf8)
            let request = try! JSONDecoder().decode(ReminderEnsureRequest.self, from: data)
            precondition(request.listTitle == "多元タスク")
            precondition(request.marker == "[watch:corp-invoice-registration]")
        },
        {
            let data = Data("""
            {"id":"calendar-training","expectedName":"fetch: Garmin","newName":"Garminコーチ","expectedSourceID":"source-1","expectedSourceName":"iCloud","expectedSourceType":2}
            """.utf8)
            let request = try! JSONDecoder().decode(CalendarRenameRequest.self, from: data)
            precondition(request.id == "calendar-training")
            precondition(request.expectedName == "fetch: Garmin")
            precondition(request.newName == "Garminコーチ")
        },
        {
            let encoded = try! encodeSnapshot(makeSnapshotResponse(
                eventStatus: AuthorizationState(raw: 3, name: "fullAccess"),
                reminderStatus: AuthorizationState(raw: 3, name: "fullAccess"),
                eventResult: .success(events), reminderResult: .success(reminders),
                containers: SnapshotContainers(
                    calendars: [personal], reminderLists: [personal])))
            let json = String(data: encoded, encoding: .utf8)!
            precondition(json.contains("2026-07-31T00:00:00Z"))
            precondition(json.contains("\"locationAlerts\""))
            precondition(json.contains("\"recurrence\""))
            precondition(json.contains("\"watchMarkers\":[\"[watch:test]\"]"))
        },
    ]

    static func main() {
        _ = checks.map { $0() }
        print("evkitd tests: \(checks.count) passed")
    }
}
