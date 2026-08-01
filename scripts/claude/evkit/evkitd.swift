// evkitd.swift — EventKit の読書きに対する唯一の署名済み TCC 境界。
//
//   f(request JSON on stdin) -> response JSON on stdout
//
// launchd の inetdCompatibility により stdin/stdout は Unix socket に接続される。
// snapshot はこの署名済みプロセス内で EventKit 公開 API を直接使う。既存の書込み op は
// canonical な adapter を子プロセスとして実行する。別daemon/cache/fallbackは持たない。

import CoreLocation
import EventKit
import Foundation

// MARK: - Immutable snapshot values and pure transforms

struct SnapshotSource: Codable, Equatable {
    let id: String
    let name: String
    let type: Int
}

struct SnapshotContainer: Codable, Equatable {
    let id: String
    let name: String
    let source: SnapshotSource
}

struct SnapshotSelectors: Codable, Equatable {
    let names: [String]
    let ids: [String]
}

struct SnapshotEvent: Codable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let location: String?
    let timeZone: String?
    let calendar: SnapshotContainer
    let source: SnapshotSource

    enum CodingKeys: String, CodingKey {
        case id, title, start, end, allDay, location, timeZone, calendar, source
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(start, forKey: .start)
        try values.encode(end, forKey: .end)
        try values.encode(allDay, forKey: .allDay)
        try location.map { try values.encode($0, forKey: .location) }
            ?? values.encodeNil(forKey: .location)
        try timeZone.map { try values.encode($0, forKey: .timeZone) }
            ?? values.encodeNil(forKey: .timeZone)
        try values.encode(calendar, forKey: .calendar)
        try values.encode(source, forKey: .source)
    }
}

struct SnapshotRecurrenceDay: Codable, Equatable {
    let day: Int
    let weekNumber: Int
}

struct SnapshotRecurrenceEnd: Codable, Equatable {
    let date: Date?
    let occurrenceCount: Int?
}

struct SnapshotRecurrence: Codable, Equatable {
    let frequency: String
    let interval: Int
    let firstDayOfWeek: Int
    let daysOfWeek: [SnapshotRecurrenceDay]
    let daysOfMonth: [Int]
    let monthsOfYear: [Int]
    let weeksOfYear: [Int]
    let daysOfYear: [Int]
    let setPositions: [Int]
    let end: SnapshotRecurrenceEnd?
    let calendarIdentifier: String
}

struct SnapshotLocationAlert: Codable, Equatable {
    let title: String?
    let latitude: Double?
    let longitude: Double?
    let radiusMeters: Double?
    let proximity: String
}

struct SnapshotReminder: Codable, Equatable {
    let id: String
    let title: String
    let due: Date?
    let dueAllDay: Bool
    let dueTimeZone: String?
    let completed: Bool
    let completedAt: Date?
    let list: SnapshotContainer
    let priority: Int
    let recurrence: [SnapshotRecurrence]
    let locationAlerts: [SnapshotLocationAlert]

    enum CodingKeys: String, CodingKey {
        case id, title, due, dueAllDay, dueTimeZone, completed, completedAt, list, priority
        case recurrence, locationAlerts
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try due.map { try values.encode($0, forKey: .due) } ?? values.encodeNil(forKey: .due)
        try values.encode(dueAllDay, forKey: .dueAllDay)
        try dueTimeZone.map { try values.encode($0, forKey: .dueTimeZone) }
            ?? values.encodeNil(forKey: .dueTimeZone)
        try values.encode(completed, forKey: .completed)
        try completedAt.map { try values.encode($0, forKey: .completedAt) }
            ?? values.encodeNil(forKey: .completedAt)
        try values.encode(list, forKey: .list)
        try values.encode(priority, forKey: .priority)
        try values.encode(recurrence, forKey: .recurrence)
        try values.encode(locationAlerts, forKey: .locationAlerts)
    }
}

struct AuthorizationState: Codable, Equatable {
    let raw: Int
    let name: String
}

struct SourceFailure: Error, Codable, Equatable {
    let code: String
    let message: String
}

struct SnapshotContainers: Codable, Equatable {
    let calendars: [SnapshotContainer]
    let reminderLists: [SnapshotContainer]
}

struct SnapshotStatus: Codable, Equatable {
    let event: AuthorizationState
    let reminder: AuthorizationState
}

struct SnapshotErrors: Codable, Equatable {
    let events: SourceFailure?
    let reminders: SourceFailure?

    enum CodingKeys: String, CodingKey { case events, reminders }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try events.map { try values.encode($0, forKey: .events) }
            ?? values.encodeNil(forKey: .events)
        try reminders.map { try values.encode($0, forKey: .reminders) }
            ?? values.encodeNil(forKey: .reminders)
    }
}

struct SnapshotResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let partial: Bool
    let status: SnapshotStatus
    let events: [SnapshotEvent]
    let reminders: [SnapshotReminder]
    let containers: SnapshotContainers
    let errors: SnapshotErrors
}

struct SnapshotRequest: Decodable {
    let rangeStart: String
    let rangeEnd: String
    let calendars: SnapshotSelectors
    let reminderLists: SnapshotSelectors
    let includeCompleted: Bool?
    let dueBefore: String?
}

let parseISO8601: (String) -> Date? = { ISO8601DateFormatter().date(from: $0) }

let authorizationState: (EKEntityType) -> AuthorizationState = { entity in
    let status = EKEventStore.authorizationStatus(for: entity)
    let name = switch status {
    case .notDetermined: "notDetermined"
    case .restricted: "restricted"
    case .denied: "denied"
    case .fullAccess: "fullAccess"
    case .writeOnly: "writeOnly"
    @unknown default: "unknown"
    }
    return AuthorizationState(raw: status.rawValue, name: name)
}

func fullAccessError(source: String, status: AuthorizationState) -> SourceFailure? {
    status.raw == EKAuthorizationStatus.fullAccess.rawValue
        ? nil
        : SourceFailure(
            code: "authorization_\(status.name)",
            message: "\(source) require full access (status=\(status.raw), \(status.name)); run evkit seed in the MacBook Air Aqua session")
}

func readWhenAuthorized<Value>(
    status: AuthorizationState, source: String, reader: () -> Value
) -> Result<Value, SourceFailure> {
    fullAccessError(source: source, status: status).map(Result.failure)
        ?? .success(reader())
}

func sortContainers(_ containers: [SnapshotContainer]) -> [SnapshotContainer] {
    containers.sorted { lhs, rhs in
        lhs.name != rhs.name ? lhs.name < rhs.name
            : lhs.source.name != rhs.source.name ? lhs.source.name < rhs.source.name
            : lhs.id < rhs.id
    }
}

func selectContainers(
    _ containers: [SnapshotContainer], selectors: SnapshotSelectors
) -> [SnapshotContainer] {
    let names = Set(selectors.names)
    let ids = Set(selectors.ids)
    return sortContainers(
        containers.filter { names.contains($0.name) || ids.contains($0.id) })
}

func sortEvents(_ events: [SnapshotEvent]) -> [SnapshotEvent] {
    events.sorted { lhs, rhs in
        lhs.start != rhs.start ? lhs.start < rhs.start
            : lhs.end != rhs.end ? lhs.end < rhs.end
            : lhs.calendar.id != rhs.calendar.id ? lhs.calendar.id < rhs.calendar.id
            : lhs.id != rhs.id ? lhs.id < rhs.id
            : lhs.title < rhs.title
    }
}

func sortReminders(_ reminders: [SnapshotReminder]) -> [SnapshotReminder] {
    reminders.sorted { lhs, rhs in
        let dueOrder: Bool? = switch (lhs.due, rhs.due) {
        case let (.some(left), .some(right)): left == right ? nil : left < right
        case (.some, .none): true
        case (.none, .some): false
        case (.none, .none): nil
        }
        return dueOrder
            ?? (lhs.list.id != rhs.list.id ? lhs.list.id < rhs.list.id
                : lhs.title != rhs.title ? lhs.title < rhs.title
                : lhs.id < rhs.id)
    }
}

func filterReminders(
    _ reminders: [SnapshotReminder], includeCompleted: Bool, dueBefore: Date?
) -> [SnapshotReminder] {
    reminders.filter { reminder in
        (includeCompleted || !reminder.completed)
            && (dueBefore.map { boundary in
                reminder.due.map { due in due <= boundary } ?? true
            } ?? true)
    }
}

extension Result where Failure == SourceFailure {
    var snapshotValue: Success? {
        switch self { case let .success(value): value; case .failure: nil }
    }

    var snapshotError: SourceFailure? {
        switch self { case .success: nil; case let .failure(error): error }
    }
}

func makeSnapshotResponse(
    eventStatus: AuthorizationState,
    reminderStatus: AuthorizationState,
    eventResult: Result<[SnapshotEvent], SourceFailure>,
    reminderResult: Result<[SnapshotReminder], SourceFailure>,
    containers: SnapshotContainers
) -> SnapshotResponse {
    let eventSucceeded = eventResult.snapshotError == nil
    let reminderSucceeded = reminderResult.snapshotError == nil
    return SnapshotResponse(
        ok: eventSucceeded && reminderSucceeded,
        op: "snapshot",
        partial: eventSucceeded != reminderSucceeded,
        status: SnapshotStatus(event: eventStatus, reminder: reminderStatus),
        events: sortEvents(eventResult.snapshotValue ?? []),
        reminders: sortReminders(reminderResult.snapshotValue ?? []),
        containers: SnapshotContainers(
            calendars: sortContainers(containers.calendars),
            reminderLists: sortContainers(containers.reminderLists)),
        errors: SnapshotErrors(
            events: eventResult.snapshotError, reminders: reminderResult.snapshotError))
}

func encodeSnapshot(_ snapshot: SnapshotResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(snapshot)
}

// MARK: - EventKit adapters

let sourceValue: (EKSource) -> SnapshotSource = {
    SnapshotSource(
        id: $0.sourceIdentifier, name: $0.title, type: $0.sourceType.rawValue)
}

let containerValue: (EKCalendar) -> SnapshotContainer = { calendar in
    SnapshotContainer(
        id: calendar.calendarIdentifier,
        name: calendar.title,
        source: sourceValue(calendar.source))
}

let selectedCalendars: ([EKCalendar], SnapshotSelectors) -> [EKCalendar] = {
    calendars, selectors in
    let names = Set(selectors.names)
    let ids = Set(selectors.ids)
    return calendars
        .filter { names.contains($0.title) || ids.contains($0.calendarIdentifier) }
        .sorted { lhs, rhs in
            lhs.title != rhs.title ? lhs.title < rhs.title
                : lhs.source.title != rhs.source.title ? lhs.source.title < rhs.source.title
                : lhs.calendarIdentifier < rhs.calendarIdentifier
        }
}

let eventValue: (EKEvent) -> SnapshotEvent = { event in
    let calendar = containerValue(event.calendar)
    return SnapshotEvent(
        id: event.eventIdentifier ?? event.calendarItemIdentifier,
        title: event.title ?? "",
        start: event.startDate,
        end: event.endDate,
        allDay: event.isAllDay,
        location: event.location,
        timeZone: event.timeZone?.identifier,
        calendar: calendar,
        source: calendar.source)
}

let recurrenceFrequency: (EKRecurrenceFrequency) -> String = {
    switch $0 {
    case .daily: "daily"
    case .weekly: "weekly"
    case .monthly: "monthly"
    case .yearly: "yearly"
    @unknown default: "unknown"
    }
}

let integerValues: ([NSNumber]?) -> [Int] = {
    ($0 ?? []).map(\.intValue).sorted()
}

let recurrenceValue: (EKRecurrenceRule) -> SnapshotRecurrence = { rule in
    let end = rule.recurrenceEnd.map {
        SnapshotRecurrenceEnd(
            date: $0.endDate,
            occurrenceCount: $0.occurrenceCount > 0 ? $0.occurrenceCount : nil)
    }
    return SnapshotRecurrence(
        frequency: recurrenceFrequency(rule.frequency),
        interval: rule.interval,
        firstDayOfWeek: rule.firstDayOfTheWeek,
        daysOfWeek: (rule.daysOfTheWeek ?? [])
            .map { SnapshotRecurrenceDay(day: $0.dayOfTheWeek.rawValue, weekNumber: $0.weekNumber) }
            .sorted { $0.day != $1.day ? $0.day < $1.day : $0.weekNumber < $1.weekNumber },
        daysOfMonth: integerValues(rule.daysOfTheMonth),
        monthsOfYear: integerValues(rule.monthsOfTheYear),
        weeksOfYear: integerValues(rule.weeksOfTheYear),
        daysOfYear: integerValues(rule.daysOfTheYear),
        setPositions: integerValues(rule.setPositions),
        end: end,
        calendarIdentifier: rule.calendarIdentifier)
}

let proximityValue: (EKAlarmProximity) -> String = {
    switch $0 {
    case .none: "none"
    case .enter: "enter"
    case .leave: "leave"
    @unknown default: "unknown"
    }
}

let locationAlertValue: (EKAlarm) -> SnapshotLocationAlert? = { alarm in
    alarm.structuredLocation.map { location in
        let coordinate = location.geoLocation?.coordinate
        return SnapshotLocationAlert(
            title: location.title,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            radiusMeters: location.radius,
            proximity: proximityValue(alarm.proximity))
    }
}

let dateValue: (DateComponents?) -> Date? = { components in
    components.flatMap { ($0.calendar ?? Calendar(identifier: .gregorian)).date(from: $0) }
}

let reminderValue: (EKReminder) -> SnapshotReminder = { reminder in
    let dueComponents = reminder.dueDateComponents
    return SnapshotReminder(
        id: reminder.calendarItemIdentifier,
        title: reminder.title ?? "",
        due: dateValue(dueComponents),
        dueAllDay: dueComponents.map {
            $0.hour == nil && $0.minute == nil && $0.second == nil
        } ?? false,
        dueTimeZone: dueComponents?.timeZone?.identifier,
        completed: reminder.isCompleted,
        completedAt: reminder.completionDate,
        list: containerValue(reminder.calendar),
        priority: reminder.priority,
        recurrence: (reminder.recurrenceRules ?? []).map(recurrenceValue),
        locationAlerts: (reminder.alarms ?? []).compactMap(locationAlertValue))
}

// MARK: - Stream boundary

#if !EVKIT_TESTING

let handlers: [String: (script: String, args: [String])] = [
    "calendar": ("/Users/tkgshn/.claude/scripts/calendar/apply.swift", ["-"]),
    "reminders.recurring": ("/Users/tkgshn/.claude/scripts/reminders/recurring.swift", []),
    "reminders.geofence": (
        "/Users/tkgshn/.claude/skills/apple-reminders-geofence/scripts/geofence_reminders.swift", []),
]

let stdoutHandle = FileHandle.standardOutput

func respondData(_ data: Data, ok: Bool) -> Never {
    stdoutHandle.write(data)
    stdoutHandle.write(Data("\n".utf8))
    exit(ok ? 0 : 1)
}

func respond(_ object: [String: Any]) -> Never {
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
        ?? Data(#"{"ok":false,"error":"response encoding failed"}"#.utf8)
    respondData(data, ok: object["ok"] as? Bool == true)
}

func fail(_ message: String, _ extra: [String: Any] = [:]) -> Never {
    respond(extra.merging(["ok": false, "error": message]) { current, _ in current })
}

func readRequestLine() -> Data {
    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
        let count = read(0, &chunk, chunk.count)
        if count <= 0 { return buffer }
        buffer.append(contentsOf: chunk[0..<count])
        if let newline = buffer.firstIndex(of: 0x0A) { return Data(buffer[..<newline]) }
    }
}

func seedAccess(_ store: EKEventStore) -> (event: AuthorizationState, reminder: AuthorizationState) {
    typealias Requester = (@escaping @Sendable (Bool, Error?) -> Void) -> Void
    let currentEvent = authorizationState(.event)
    let currentReminder = authorizationState(.reminder)
    let requests: [Requester] = [
        currentEvent.raw == EKAuthorizationStatus.fullAccess.rawValue
            ? nil : { store.requestFullAccessToEvents(completion: $0) },
        currentReminder.raw == EKAuthorizationStatus.fullAccess.rawValue
            ? nil : { store.requestFullAccessToReminders(completion: $0) },
    ].compactMap { $0 }
    _ = requests.map { requester in
        let semaphore = DispatchSemaphore(value: 0)
        requester { _, _ in semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + 180)
    }
    return (authorizationState(.event), authorizationState(.reminder))
}

func snapshotResult(
    store: EKEventStore, specData: Data,
    eventStatus: AuthorizationState, reminderStatus: AuthorizationState
) -> Never {
    guard let request = try? JSONDecoder().decode(SnapshotRequest.self, from: specData),
        let rangeStart = parseISO8601(request.rangeStart),
        let rangeEnd = parseISO8601(request.rangeEnd),
        rangeStart < rangeEnd,
        request.dueBefore == nil || request.dueBefore.flatMap(parseISO8601) != nil
    else { fail("bad snapshot spec: require ISO8601 rangeStart < rangeEnd and valid dueBefore") }
    let dueBefore = request.dueBefore.flatMap(parseISO8601)

    let eventCalendarsResult: Result<[EKCalendar], SourceFailure> = readWhenAuthorized(
        status: eventStatus, source: "events",
        reader: { selectedCalendars(store.calendars(for: .event), request.calendars) })
    let reminderListsResult: Result<[EKCalendar], SourceFailure> = readWhenAuthorized(
        status: reminderStatus, source: "reminders",
        reader: { selectedCalendars(store.calendars(for: .reminder), request.reminderLists) })
    let eventCalendars = eventCalendarsResult.snapshotValue ?? []
    let reminderLists = reminderListsResult.snapshotValue ?? []
    let containers = SnapshotContainers(
        calendars: eventCalendars.map(containerValue),
        reminderLists: reminderLists.map(containerValue))

    let eventResult: Result<[SnapshotEvent], SourceFailure> = eventCalendarsResult.map { calendars in
        calendars.isEmpty ? [] : store.events(matching: store.predicateForEvents(
            withStart: rangeStart, end: rangeEnd, calendars: calendars)).map(eventValue)
    }

    let finish: (Result<[SnapshotReminder], SourceFailure>) -> Never = { reminderResult in
        let response = makeSnapshotResponse(
            eventStatus: eventStatus,
            reminderStatus: reminderStatus,
            eventResult: eventResult,
            reminderResult: reminderResult,
            containers: containers)
        return (try? encodeSnapshot(response)).map {
            respondData($0, ok: response.ok)
        } ?? fail("snapshot response encoding failed")
    }

    _ = reminderListsResult.snapshotError.map { finish(.failure($0)) }
    guard !reminderLists.isEmpty else { finish(.success([])) }

    let predicate = store.predicateForReminders(in: reminderLists)
    _ = store.fetchReminders(matching: predicate) { reminders in
        let result: Result<[SnapshotReminder], SourceFailure> = reminders.map {
            .success(filterReminders(
                $0.map(reminderValue),
                includeCompleted: request.includeCompleted ?? false,
                dueBefore: dueBefore))
        } ?? .failure(SourceFailure(
            code: "fetch_failed", message: "EventKit returned no reminder result"))
        finish(result)
    }
    dispatchMain()
}

func runChild(
    handler: (script: String, args: [String]), specData: Data,
    op: String, statusJSON: [String: Any]
) -> Never {
    let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("evkitd-\(getpid())", isDirectory: true)
    try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

    let outURL = scratch.appendingPathComponent("out")
    let errURL = scratch.appendingPathComponent("err")
    let inURL = scratch.appendingPathComponent("in")
    guard (try? specData.write(to: inURL)) != nil,
        FileManager.default.createFile(atPath: outURL.path, contents: nil),
        FileManager.default.createFile(atPath: errURL.path, contents: nil),
        let inHandle = try? FileHandle(forReadingFrom: inURL),
        let outHandle = try? FileHandle(forWritingTo: outURL),
        let errHandle = try? FileHandle(forWritingTo: errURL)
    else { fail("cannot stage scratch files") }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    task.arguments = [handler.script] + handler.args
    task.standardInput = inHandle
    task.standardOutput = outHandle
    task.standardError = errHandle

    do { try task.run() } catch { fail("cannot spawn \(handler.script): \(error)") }
    task.waitUntilExit()

    let childOut = (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
    let childErr = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
    try? FileManager.default.removeItem(at: scratch)
    respond([
        "ok": task.terminationStatus == 0,
        "op": op,
        "exit": Int(task.terminationStatus),
        "stdout": childOut,
        "stderr": childErr,
        "status": statusJSON,
    ])
}

func runBridge() -> Never {
    guard
        let request = (try? JSONSerialization.jsonObject(with: readRequestLine())) as? [String: Any],
        let op = request["op"] as? String
    else { fail("bad request JSON (expect a single line {\"op\":…})") }

    let eventStatus = authorizationState(.event)
    let reminderStatus = authorizationState(.reminder)
    let rawStatus: [String: Any] = ["event": eventStatus.raw, "reminder": reminderStatus.raw]

    if op == "status" {
        respond([
            "ok": eventStatus.raw == 3 && reminderStatus.raw == 3,
            "status": rawStatus,
            "bundleID": Bundle.main.bundleIdentifier ?? "(none)",
        ])
    }

    if op == "seed" {
        let seeded = seedAccess(EKEventStore())
        respond([
            "ok": seeded.event.raw == 3 && seeded.reminder.raw == 3,
            "status": ["event": seeded.event.raw, "reminder": seeded.reminder.raw],
            "bundleID": Bundle.main.bundleIdentifier ?? "(none)",
        ])
    }

    guard let spec = request["spec"], JSONSerialization.isValidJSONObject(spec),
        let specData = try? JSONSerialization.data(withJSONObject: spec)
    else { fail("op \(op) requires a JSON object in spec") }

    let store = EKEventStore()
    if op == "snapshot" {
        snapshotResult(
            store: store, specData: specData,
            eventStatus: eventStatus, reminderStatus: reminderStatus)
    }

    guard let handler = handlers[op] else {
        fail("unknown op: \(op)", ["ops": Array(handlers.keys).sorted() + ["snapshot", "status", "seed"]])
    }

    let needsEvent = op == "calendar"
    let requiredStatus = needsEvent ? eventStatus : reminderStatus
    let requiredSource = needsEvent ? "calendar" : "reminders"
    _ = fullAccessError(source: requiredSource, status: requiredStatus).map {
        fail($0.message, ["code": $0.code, "status": rawStatus])
    }
    runChild(handler: handler, specData: specData, op: op, statusJSON: rawStatus)
}

@main
enum EventKitBridgeMain {
    static func main() {
        runBridge()
    }
}

#endif
