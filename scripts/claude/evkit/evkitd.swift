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
import AppKit

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

struct CalendarLedgerEntry: Codable, Equatable {
    let id: String
    let name: String
    let source: SnapshotSource
    let writable: Bool
    let colorHex: String?
    let eventCount: Int
    let firstEventStart: Date?
    let lastEventEnd: Date?
    let representativeTitles: [String]
}

struct CalendarCatalogResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let status: AuthorizationState
    let calendars: [CalendarLedgerEntry]
    let error: SourceFailure?
}

struct CalendarDeleteRequest: Decodable {
    let id: String
    let expectedName: String
    let expectedSourceID: String
    let expectedSourceName: String
    let expectedSourceType: Int
    let expectedEventCount: Int
}

struct CalendarDeleteResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let removed: CalendarLedgerEntry?
    let error: SourceFailure?
}

struct CalendarRenameRequest: Decodable {
    let id: String
    let expectedName: String
    let newName: String
    let expectedSourceID: String
    let expectedSourceName: String
    let expectedSourceType: Int
    let allowReadOnly: Bool
}

struct CalendarRenameResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let id: String?
    let oldName: String?
    let newName: String?
    let error: SourceFailure?
}

struct CalendarMergeRequest: Decodable {
    let sourceID: String
    let targetID: String
    let expectedSourceName: String
    let expectedTargetName: String
    let expectedSourceSourceID: String
    let expectedSourceSourceName: String
    let expectedSourceSourceType: Int
    let expectedTargetSourceID: String
    let expectedTargetSourceName: String
    let expectedTargetSourceType: Int
    let expectedSourceEventCount: Int
    let expectedTargetEventCount: Int
    let removeSource: Bool
}

struct CalendarMergeResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let sourceID: String?
    let targetID: String?
    let movedEventCount: Int
    let sourceRemoved: Bool
    let error: SourceFailure?
}

struct CalendarColorTarget: Decodable {
    let id: String
    let expectedName: String
    let expectedSourceID: String
    let expectedSourceName: String
    let expectedSourceType: Int
}

struct CalendarColorGroup: Decodable {
    let color: String
    let calendars: [CalendarColorTarget]
}

struct CalendarColorRequest: Decodable {
    let groups: [CalendarColorGroup]
    let allowReadOnly: Bool
}

struct CalendarColorChange: Codable, Equatable {
    let id: String
    let name: String
    let oldColorHex: String?
    let newColorHex: String
}

struct CalendarColorResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let changes: [CalendarColorChange]
    let error: SourceFailure?
}

struct EventMoveRequest: Decodable {
    let eventID: String
    let sourceCalendarID: String
    let targetCalendarID: String
    let expectedTitle: String
    let expectedStart: String
    let expectedEnd: String
    let expectedSourceName: String
    let expectedSourceSourceID: String
    let expectedSourceSourceType: Int
    let expectedTargetName: String
    let expectedTargetSourceID: String
    let expectedTargetSourceType: Int
}

struct EventMoveResponse: Codable, Equatable {
    let ok: Bool
    let op: String
    let eventID: String?
    let sourceCalendarID: String?
    let targetCalendarID: String?
    let error: SourceFailure?
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
    // The bridge deliberately projects only its own stable marker rather than
    // exposing arbitrary private event notes to a consumer.
    let beeperCrmMessageId: String?
    let calendar: SnapshotContainer
    let source: SnapshotSource

    enum CodingKeys: String, CodingKey {
        case id, title, start, end, allDay, location, timeZone, beeperCrmMessageId, calendar, source
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
        try beeperCrmMessageId.map { try values.encode($0, forKey: .beeperCrmMessageId) }
            ?? values.encodeNil(forKey: .beeperCrmMessageId)
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

let representativeTitles: ([EKEvent]) -> [String] = { events in
    Array(Set(events.compactMap(\.title).filter { !$0.isEmpty }).sorted().prefix(5))
}

let colorHex: (CGColor?) -> String? = { color in
    color.flatMap { NSColor(cgColor: $0)?.usingColorSpace(.sRGB) }.map { color in
        String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded()))
    }
}

let parseColorHex: (String) -> CGColor? = { value in
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
    guard normalized.count == 6,
        let red = Int(normalized.prefix(2), radix: 16),
        let green = Int(normalized.dropFirst(2).prefix(2), radix: 16),
        let blue = Int(normalized.dropFirst(4).prefix(2), radix: 16)
    else { return nil }
    return CGColor(
        red: CGFloat(red) / 255,
        green: CGFloat(green) / 255,
        blue: CGFloat(blue) / 255,
        alpha: 1)
}

let calendarLedgerEntry: (EKCalendar, [EKEvent]) -> CalendarLedgerEntry = { calendar, events in
    CalendarLedgerEntry(
        id: calendar.calendarIdentifier,
        name: calendar.title,
        source: sourceValue(calendar.source),
        writable: calendar.allowsContentModifications,
        colorHex: colorHex(calendar.cgColor),
        eventCount: events.count,
        firstEventStart: events.map(\.startDate).min(),
        lastEventEnd: events.map(\.endDate).max(),
        representativeTitles: representativeTitles(events))
}

let calendarDeletionMatches: (CalendarDeleteRequest, CalendarLedgerEntry) -> Bool = { request, entry in
    request.expectedEventCount == entry.eventCount
        && request.expectedName == entry.name
        && request.expectedSourceID == entry.source.id
        && request.expectedSourceName == entry.source.name
        && request.expectedSourceType == entry.source.type
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

let beeperCrmMessageId: (String?) -> String? = { notes in
    notes?.split(separator: "\n")
        .compactMap { line in
            line.hasPrefix("beeper-crm:msg:")
                ? String(line.dropFirst("beeper-crm:msg:".count))
                : nil
        }
        .first
        .flatMap { $0.isEmpty ? nil : $0 }
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
        beeperCrmMessageId: beeperCrmMessageId(event.notes),
        calendar: calendar,
        source: calendar.source)
}

let calendarEvents: (EKEventStore, EKCalendar) -> [EKEvent] = { store, calendar in
    let gregorian = Calendar(identifier: .gregorian)
    let now = Date()
    let ranges = (-3..<3).compactMap { offset -> (Date, Date)? in
        let rangeStart = gregorian.date(byAdding: .year, value: offset, to: now)
        let rangeEnd = gregorian.date(byAdding: .year, value: offset + 1, to: now)
        return rangeStart.flatMap { first in rangeEnd.map { (first, $0) } }
    }
    let events = ranges.flatMap { range in
        store.events(matching: store.predicateForEvents(
            withStart: range.0, end: range.1, calendars: [calendar]))
    }
    return Array(events.reduce(into: [String: EKEvent]()) { result, event in
        let title = event.title ?? ""
        let key = "\(event.calendarItemIdentifier)|\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)|\(title)"
        result[key] = event
    }.values)
}

let allCalendarEvents: (EKEventStore, EKCalendar) -> [EKEvent] = { store, calendar in
    let gregorian = Calendar(identifier: .gregorian)
    let base = gregorian.date(from: DateComponents(year: 2000, month: 1, day: 1))!
    let ranges = (0..<100).compactMap { offset -> (Date, Date)? in
        let rangeStart = gregorian.date(byAdding: .year, value: offset, to: base)
        let rangeEnd = gregorian.date(byAdding: .year, value: offset + 1, to: base)
        return rangeStart.flatMap { first in rangeEnd.map { (first, $0) } }
    }
    let events = ranges.flatMap { range in
        store.events(matching: store.predicateForEvents(
            withStart: range.0, end: range.1, calendars: [calendar]))
    }
    return Array(events.reduce(into: [String: EKEvent]()) { result, event in
        let title = event.title ?? ""
        let key = "\(event.calendarItemIdentifier)|\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)|\(title)"
        result[key] = event
    }.values)
}

let eventIdentity: (EKEvent) -> String = { event in
    let title = event.title ?? ""
    let location = event.location ?? ""
    return "\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)|\(title)|\(location)"
}

func encodeCalendarCatalog(_ response: CalendarCatalogResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(response)
}

func encodeCalendarDelete(_ response: CalendarDeleteResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(response)
}

func encodeCalendarRename(_ response: CalendarRenameResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(response)
}

func encodeCalendarMerge(_ response: CalendarMergeResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(response)
}

func encodeCalendarColor(_ response: CalendarColorResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(response)
}

func encodeEventMove(_ response: EventMoveResponse) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(response)
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
    // セクションは EventKit に無い(private ReminderKit を使う)。詳細は section.swift の冒頭。
    "reminders.section": ("/Users/tkgshn/.claude/scripts/reminders/section.swift", []),
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

func calendarCatalogResult(store: EKEventStore, status: AuthorizationState) -> Never {
    let failure = fullAccessError(source: "events", status: status)
    guard failure == nil else {
        let response = CalendarCatalogResponse(
            ok: false, op: "calendar.catalog", status: status,
            calendars: [], error: failure)
        return (try? encodeCalendarCatalog(response)).map {
            respondData($0, ok: false)
        } ?? fail("calendar catalog response encoding failed")
    }
    let calendars = store.calendars(for: .event)
    let unsortedEntries = calendars.map { calendar in
        calendarLedgerEntry(calendar, calendarEvents(store, calendar))
    }
    let entries = unsortedEntries.sorted { lhs, rhs in
            lhs.name != rhs.name ? lhs.name < rhs.name
                : lhs.source.name != rhs.source.name ? lhs.source.name < rhs.source.name
                : lhs.id < rhs.id
        }
    let response = CalendarCatalogResponse(
        ok: true, op: "calendar.catalog", status: status,
        calendars: entries, error: nil)
    return (try? encodeCalendarCatalog(response)).map {
        respondData($0, ok: true)
    } ?? fail("calendar catalog response encoding failed")
}

func calendarDeleteResult(
    store: EKEventStore, specData: Data, status: AuthorizationState
) -> Never {
    guard let request = try? JSONDecoder().decode(CalendarDeleteRequest.self, from: specData)
    else { fail("bad calendar.delete spec") }
    _ = fullAccessError(source: "events", status: status).map {
        fail($0.message, ["code": $0.code, "status": status.raw])
    }
    guard request.expectedEventCount == 0 else {
        fail("calendar.delete requires expectedEventCount=0")
    }
    guard let calendar = store.calendars(for: .event)
        .first(where: { $0.calendarIdentifier == request.id })
    else { fail("calendar not found: \(request.id)") }
    let entry = calendarLedgerEntry(calendar, allCalendarEvents(store, calendar))
    guard calendarDeletionMatches(request, entry) else {
        fail("calendar precondition mismatch", [
            "actual": [
                "id": entry.id, "name": entry.name, "sourceID": entry.source.id,
                "sourceName": entry.source.name, "sourceType": entry.source.type,
                "eventCount": entry.eventCount,
            ],
        ])
    }
    guard entry.eventCount == 0 else { fail("calendar is not empty") }
    guard calendar.allowsContentModifications else { fail("calendar is not writable") }
    do {
        try store.removeCalendar(calendar, commit: true)
    } catch {
        fail("calendar delete failed: \(error)")
    }
    let response = CalendarDeleteResponse(ok: true, op: "calendar.delete", removed: entry, error: nil)
    return (try? encodeCalendarDelete(response)).map {
        respondData($0, ok: true)
    } ?? fail("calendar delete response encoding failed")
}

func calendarRenameResult(
    store: EKEventStore, specData: Data, status: AuthorizationState
) -> Never {
    guard let request = try? JSONDecoder().decode(CalendarRenameRequest.self, from: specData)
    else { fail("bad calendar.rename spec") }
    _ = fullAccessError(source: "events", status: status).map {
        fail($0.message, ["code": $0.code, "status": status.raw])
    }
    let newName = request.newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !newName.isEmpty, newName != request.expectedName else {
        fail("calendar.rename requires a distinct non-empty newName")
    }
    guard request.allowReadOnly else {
        fail("calendar.rename requires explicit allowReadOnly=true for a read-only calendar")
    }
    guard let calendar = store.calendars(for: .event)
        .first(where: { $0.calendarIdentifier == request.id })
    else { fail("calendar not found: \(request.id)") }
    let actualSource = sourceValue(calendar.source)
    guard calendar.title == request.expectedName,
        actualSource.id == request.expectedSourceID,
        actualSource.name == request.expectedSourceName,
        actualSource.type == request.expectedSourceType
    else { fail("calendar rename precondition mismatch") }
    let oldName = calendar.title
    calendar.title = newName
    do {
        try store.saveCalendar(calendar, commit: true)
    } catch {
        fail("calendar rename failed: \(error)")
    }
    let response = CalendarRenameResponse(
        ok: true, op: "calendar.rename", id: calendar.calendarIdentifier,
        oldName: oldName, newName: newName, error: nil)
    return (try? encodeCalendarRename(response)).map {
        respondData($0, ok: true)
    } ?? fail("calendar rename response encoding failed")
}

func calendarMergeResult(
    store: EKEventStore, specData: Data, status: AuthorizationState
) -> Never {
    guard let request = try? JSONDecoder().decode(CalendarMergeRequest.self, from: specData)
    else { fail("bad calendar.merge spec") }
    _ = fullAccessError(source: "events", status: status).map {
        fail($0.message, ["code": $0.code, "status": status.raw])
    }
    guard request.sourceID != request.targetID else {
        fail("calendar.merge requires distinct sourceID and targetID")
    }
    guard let source = store.calendars(for: .event)
        .first(where: { $0.calendarIdentifier == request.sourceID }),
        let target = store.calendars(for: .event)
        .first(where: { $0.calendarIdentifier == request.targetID })
    else { fail("calendar.merge source or target not found") }
    let sourceEntry = calendarLedgerEntry(source, allCalendarEvents(store, source))
    let targetEntry = calendarLedgerEntry(target, allCalendarEvents(store, target))
    let sourceIdentity = sourceEntry.source
    let targetIdentity = targetEntry.source
    guard sourceEntry.name == request.expectedSourceName,
        targetEntry.name == request.expectedTargetName,
        sourceIdentity.id == request.expectedSourceSourceID,
        sourceIdentity.name == request.expectedSourceSourceName,
        sourceIdentity.type == request.expectedSourceSourceType,
        targetIdentity.id == request.expectedTargetSourceID,
        targetIdentity.name == request.expectedTargetSourceName,
        targetIdentity.type == request.expectedTargetSourceType,
        sourceEntry.eventCount == request.expectedSourceEventCount,
        targetEntry.eventCount == request.expectedTargetEventCount
    else { fail("calendar.merge precondition mismatch") }
    guard source.allowsContentModifications, target.allowsContentModifications else {
        fail("calendar.merge requires writable source and target")
    }
    let targetKeys = Set(allCalendarEvents(store, target).map(eventIdentity))
    let conflicts = allCalendarEvents(store, source).filter {
        targetKeys.contains(eventIdentity($0))
    }
    guard conflicts.isEmpty else {
        fail("calendar.merge found exact event conflicts: \(conflicts.count)")
    }
    let sourceEvents = allCalendarEvents(store, source)
    do {
        _ = try sourceEvents.map { event in
            event.calendar = target
            try store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    } catch {
        fail("calendar.merge move failed: \(error)")
    }
    let remaining = allCalendarEvents(store, source).count
    guard remaining == 0 else {
        fail("calendar.merge move incomplete; source still has \(remaining) events")
    }
    let sourceRemoved: Bool = request.removeSource
        ? ((try? store.removeCalendar(source, commit: true)) != nil)
        : false
    guard !request.removeSource || sourceRemoved else {
        fail("calendar.merge moved events but could not remove empty source calendar")
    }
    let response = CalendarMergeResponse(
        ok: true, op: "calendar.merge", sourceID: request.sourceID,
        targetID: request.targetID, movedEventCount: sourceEvents.count,
        sourceRemoved: sourceRemoved, error: nil)
    return (try? encodeCalendarMerge(response)).map {
        respondData($0, ok: true)
    } ?? fail("calendar merge response encoding failed")
}

func calendarColorResult(
    store: EKEventStore, specData: Data, status: AuthorizationState
) -> Never {
    guard let request = try? JSONDecoder().decode(CalendarColorRequest.self, from: specData)
    else { fail("bad calendar.color spec") }
    _ = fullAccessError(source: "events", status: status).map {
        fail($0.message, ["code": $0.code, "status": status.raw])
    }
    guard request.allowReadOnly else {
        fail("calendar.color requires explicit allowReadOnly=true for shared calendars")
    }
    let groups = request.groups.compactMap { group -> (CalendarColorGroup, CGColor, String)? in
        parseColorHex(group.color).flatMap { color in
            colorHex(color).map { canonical in (group, color, canonical) }
        }
    }
    guard !groups.isEmpty, groups.count == request.groups.count else {
        fail("calendar.color requires non-empty six-digit hex colors")
    }
    let targets = groups.flatMap { group in group.0.calendars }
    guard !targets.isEmpty, Set(targets.map(\.id)).count == targets.count else {
        fail("calendar.color requires distinct non-empty calendar IDs")
    }
    let calendars = store.calendars(for: .event)
    let resolved = targets.compactMap { target -> (EKCalendar, CGColor, String)? in
        guard let calendar = calendars.first(where: { $0.calendarIdentifier == target.id }) else {
            return nil
        }
        let source = sourceValue(calendar.source)
        guard calendar.title == target.expectedName,
            source.id == target.expectedSourceID,
            source.name == target.expectedSourceName,
            source.type == target.expectedSourceType
        else { return nil }
        let group = groups.first(where: { $0.0.calendars.contains(where: { $0.id == target.id }) })!
        return (calendar, group.1, group.2)
    }
    guard resolved.count == targets.count else {
        fail("calendar.color precondition mismatch")
    }
    let changes = resolved.map { calendar, _, canonical in
        CalendarColorChange(
            id: calendar.calendarIdentifier,
            name: calendar.title,
            oldColorHex: colorHex(calendar.cgColor),
            newColorHex: canonical)
    }
    do {
        _ = try resolved.map { calendar, color, _ in
            calendar.cgColor = color
            try store.saveCalendar(calendar, commit: false)
        }
        try store.commit()
    } catch {
        fail("calendar color update failed: \(error)")
    }
    guard resolved.allSatisfy({ colorHex($0.0.cgColor) == $0.2 }) else {
        fail("calendar color update readback mismatch")
    }
    let response = CalendarColorResponse(
        ok: true, op: "calendar.color", changes: changes, error: nil)
    return (try? encodeCalendarColor(response)).map {
        respondData($0, ok: true)
    } ?? fail("calendar color response encoding failed")
}

func eventMoveResult(
    store: EKEventStore, specData: Data, status: AuthorizationState
) -> Never {
    guard let request = try? JSONDecoder().decode(EventMoveRequest.self, from: specData),
        let expectedStart = parseISO8601(request.expectedStart),
        let expectedEnd = parseISO8601(request.expectedEnd),
        expectedStart < expectedEnd,
        request.sourceCalendarID != request.targetCalendarID
    else { fail("bad event.move spec") }
    _ = fullAccessError(source: "events", status: status).map {
        fail($0.message, ["code": $0.code, "status": status.raw])
    }
    let calendars = store.calendars(for: .event)
    guard let source = calendars.first(where: { $0.calendarIdentifier == request.sourceCalendarID }),
        let target = calendars.first(where: { $0.calendarIdentifier == request.targetCalendarID })
    else { fail("event.move source or target not found") }
    let sourceValueSnapshot = sourceValue(source.source)
    let targetValueSnapshot = sourceValue(target.source)
    guard source.title == request.expectedSourceName,
        sourceValueSnapshot.id == request.expectedSourceSourceID,
        sourceValueSnapshot.type == request.expectedSourceSourceType,
        target.title == request.expectedTargetName,
        targetValueSnapshot.id == request.expectedTargetSourceID,
        targetValueSnapshot.type == request.expectedTargetSourceType,
        source.allowsContentModifications,
        target.allowsContentModifications
    else { fail("event.move calendar precondition mismatch") }
    let sourceEvents = allCalendarEvents(store, source)
    guard let event = store.event(withIdentifier: request.eventID)
        ?? sourceEvents.first(where: { $0.calendarItemIdentifier == request.eventID })
    else { fail("event.move event not found: \(request.eventID)") }
    guard event.title == request.expectedTitle,
        event.startDate == expectedStart,
        event.endDate == expectedEnd,
        event.calendar?.calendarIdentifier == request.sourceCalendarID
    else { fail("event.move event precondition mismatch") }
    let targetConflict = allCalendarEvents(store, target).contains {
        eventIdentity($0) == eventIdentity(event)
    }
    guard !targetConflict else { fail("event.move found an exact target conflict") }
    do {
        event.calendar = target
        try store.save(event, span: .thisEvent, commit: true)
    } catch {
        fail("event.move failed: \(error)")
    }
    let moved = allCalendarEvents(store, target).first {
        eventIdentity($0) == eventIdentity(event)
    }
    guard let moved, moved.calendar?.calendarIdentifier == request.targetCalendarID else {
        fail("event.move readback mismatch")
    }
    let response = EventMoveResponse(
        ok: true, op: "event.move", eventID: moved.calendarItemIdentifier,
        sourceCalendarID: request.sourceCalendarID,
        targetCalendarID: request.targetCalendarID, error: nil)
    return (try? encodeEventMove(response)).map {
        respondData($0, ok: true)
    } ?? fail("event move response encoding failed")
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

    let store = EKEventStore()
    if op == "calendar.catalog" {
        calendarCatalogResult(store: store, status: eventStatus)
    }

    guard let spec = request["spec"], JSONSerialization.isValidJSONObject(spec),
        let specData = try? JSONSerialization.data(withJSONObject: spec)
    else { fail("op \(op) requires a JSON object in spec") }

    if op == "calendar.delete" {
        calendarDeleteResult(store: store, specData: specData, status: eventStatus)
    }
    if op == "calendar.rename" {
        calendarRenameResult(store: store, specData: specData, status: eventStatus)
    }
    if op == "calendar.merge" {
        calendarMergeResult(store: store, specData: specData, status: eventStatus)
    }
    if op == "calendar.color" {
        calendarColorResult(store: store, specData: specData, status: eventStatus)
    }
    if op == "event.move" {
        eventMoveResult(store: store, specData: specData, status: eventStatus)
    }
    if op == "snapshot" {
        snapshotResult(
            store: store, specData: specData,
            eventStatus: eventStatus, reminderStatus: reminderStatus)
    }

    guard let handler = handlers[op] else {
        fail("unknown op: \(op)", ["ops": Array(handlers.keys).sorted() + ["calendar.catalog", "calendar.delete", "calendar.rename", "calendar.merge", "calendar.color", "event.move", "snapshot", "status", "seed"]])
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
