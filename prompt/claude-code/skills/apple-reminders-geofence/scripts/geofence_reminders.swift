#!/usr/bin/env swift
import CoreLocation
import EventKit
import Foundation

struct Payload: Decodable {
  let marker: String
  let calendarTitle: String?
  let replaceIncompleteMatchingMarker: Bool?
  let items: [ReminderItem]
}

struct ReminderItem: Decodable {
  let title: String
  let notes: String
  let locationTitle: String
  let latitude: Double
  let longitude: Double
  let radiusMeters: Double
  let priority: Int?
  let proximity: Proximity?
}

enum Proximity: String, Decodable {
  case enter
  case leave

  var eventKitValue: EKAlarmProximity {
    self == .leave ? .leave : .enter
  }
}

struct AlarmSummary: Encodable {
  let locationTitle: String?
  let radiusMeters: Double?
  let latitude: Double?
  let longitude: Double?
  let proximityRawValue: Int
}

struct ReminderSummary: Encodable {
  let title: String
  let calendarTitle: String
  let priority: Int
  let alarms: [AlarmSummary]
}

struct Summary: Encodable {
  let ok: Bool
  let error: String?
  let granted: Bool
  let calendarTitle: String?
  let removed: Int
  let created: Int
  let expected: Int
  let committed: Bool
  let reminders: [ReminderSummary]
}

let encode = { (summary: Summary) -> String in
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return (try? encoder.encode(summary))
    .flatMap { String(data: $0, encoding: .utf8) }
    ?? "{\"ok\":false,\"error\":\"failed to encode summary\"}"
}

let emit = { (summary: Summary) -> Void in
  print(encode(summary))
}

let emptySummary = { (ok: Bool, error: String?, granted: Bool) in
  Summary(
    ok: ok,
    error: error,
    granted: granted,
    calendarTitle: nil,
    removed: 0,
    created: 0,
    expected: 0,
    committed: false,
    reminders: []
  )
}

let input = FileHandle.standardInput.readDataToEndOfFile()
let decoded = try? JSONDecoder().decode(Payload.self, from: input)

let summarizeAlarm = { (alarm: EKAlarm) -> AlarmSummary in
  let location = alarm.structuredLocation
  let coordinate = location?.geoLocation?.coordinate
  return AlarmSummary(
    locationTitle: location?.title,
    radiusMeters: location?.radius,
    latitude: coordinate?.latitude,
    longitude: coordinate?.longitude,
    proximityRawValue: alarm.proximity.rawValue
  )
}

let summarizeReminder = { (reminder: EKReminder) -> ReminderSummary in
  ReminderSummary(
    title: reminder.title ?? "",
    calendarTitle: reminder.calendar.title,
    priority: reminder.priority,
    alarms: (reminder.alarms ?? []).map(summarizeAlarm)
  )
}

let createAlarm = { (item: ReminderItem) -> EKAlarm in
  let alarm = EKAlarm()
  let location = EKStructuredLocation(title: item.locationTitle)
  location.geoLocation = CLLocation(latitude: item.latitude, longitude: item.longitude)
  location.radius = item.radiusMeters
  alarm.structuredLocation = location
  alarm.proximity = (item.proximity ?? .enter).eventKitValue
  return alarm
}

let run = { (payload: Payload) -> Int32 in
  let store = EKEventStore()
  let requestDone = DispatchSemaphore(value: 0)
  let saveDone = DispatchSemaphore(value: 0)

  let selectedCalendar = { () -> EKCalendar? in
    payload.calendarTitle
      .flatMap { title in store.calendars(for: .reminder).first { $0.title == title } }
      ?? store.defaultCalendarForNewReminders()
      ?? store.calendars(for: .reminder).first
  }

  let verify = { (calendarTitle: String?, removed: Int, created: Int, committed: Bool) -> Void in
    let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
    store.fetchReminders(matching: predicate) { reminders in
      let matching = (reminders ?? [])
        .filter { ($0.notes ?? "").contains(payload.marker) }
        .map(summarizeReminder)
      emit(
        Summary(
          ok: committed && created == payload.items.count,
          error: committed ? nil : "EventKit commit failed",
          granted: true,
          calendarTitle: calendarTitle,
          removed: removed,
          created: created,
          expected: payload.items.count,
          committed: committed,
          reminders: matching
        )
      )
      saveDone.signal()
    }
  }

  let save = { () -> Void in
    let calendar = selectedCalendar()
    calendar.map { targetCalendar in
      let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
      store.fetchReminders(matching: predicate) { existingReminders in
        let shouldReplace = payload.replaceIncompleteMatchingMarker ?? true
        let removed = shouldReplace
          ? (existingReminders ?? [])
            .filter { ($0.notes ?? "").contains(payload.marker) }
            .map { (try? store.remove($0, commit: false)).map { 1 } ?? 0 }
            .reduce(0, +)
          : 0
        let created = payload.items
          .map { item -> Int in
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = targetCalendar
            reminder.title = item.title
            reminder.notes = "\(item.notes)\n\n\(payload.marker)"
            reminder.priority = item.priority ?? 0
            reminder.addAlarm(createAlarm(item))
            return (try? store.save(reminder, commit: false)).map { 1 } ?? 0
          }
          .reduce(0, +)
        let committed = (try? store.commit()).map { true } ?? false
        verify(targetCalendar.title, removed, created, committed)
      }
    } ?? {
      emit(emptySummary(false, "No writable Reminders calendar found", true))
      saveDone.signal()
    }()
  }

  let requestAccess = { (completion: @escaping (Bool, Error?) -> Void) -> Void in
    if #available(macOS 14.0, *) {
      store.requestFullAccessToReminders(completion: completion)
    } else {
      store.requestAccess(to: .reminder, completion: completion)
    }
  }

  requestAccess { granted, error in
    granted
      ? save()
      : {
        emit(emptySummary(false, error?.localizedDescription ?? "Reminders access was not granted", false))
        saveDone.signal()
      }()
    requestDone.signal()
  }

  requestDone.wait()
  saveDone.wait()
  return 0
}

let exitCode = decoded.map(run) ?? {
  emit(emptySummary(false, "Invalid JSON payload", false))
  return 2
}()

exit(exitCode)
