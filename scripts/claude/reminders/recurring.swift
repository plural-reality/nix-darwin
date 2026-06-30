#!/usr/bin/env swift
// recurring.swift — 時刻＋繰り返し Apple Reminders の唯一の IO 境界（汎用プリミティブ）。
// f(宣言的 JSON spec on stdin) -> iCloud Reminders 副作用 -> 検証 JSON on stdout。
//
// geofence_reminders.swift の姉妹。item ごとに 2 つの通知モデルを選べる:
//   (A) due-time : 期日の時刻そのものが通知時刻。recurrence の曜日 = その時刻の曜日。1回・確実。
//                  例) 収集の「前日」曜日 22:00 を期日に → 前日22:00 に1回鳴る。"dueClock":"22:00"
//   (B) alarm    : 期日 = 収集日（recurrence を正確に保つ）、通知 = EKAlarm(relativeOffset) で前日へずらす。
//                  「第2・第4土曜の前日(金)」は曜日繰り返しで表せない → このモデルが必要。"alarm":{...}
//   両方未指定なら日付のみ期日（通知はOS既定／不確実）。両方指定すれば「期日時刻＋追加アラーム」。
//
// usage:  swift recurring.swift < spec.json
// spec:
// { "marker":"[stable]", "listTitle":"ゴミ捨て", "replaceIncompleteMatchingMarker":true,
//   "items":[
//     { "title":"…","notes":"…",
//       "recurrence":{"freq":"weekly","weekdays":[2,5]},   // 1=Sun..7=Sat
//       "dueClock":"22:00" },                               // モデルA
//     { "title":"…","notes":"…",
//       "recurrence":{"freq":"monthly","monthlyWeekdays":[{"day":7,"week":2},{"day":7,"week":4}]},
//       "alarm":{"dayOffset":-1,"clock":"22:00"} } ] }      // モデルB
import EventKit
import Foundation

struct MonthlySpec: Decodable { let day: Int; let week: Int }
struct Recurrence: Decodable { let freq: String; let weekdays: [Int]?; let monthlyWeekdays: [MonthlySpec]? }
struct AlarmSpec: Decodable { let dayOffset: Int; let clock: String }
struct Item: Decodable {
  let title: String
  let notes: String
  let recurrence: Recurrence
  let dueClock: String?
  let alarm: AlarmSpec?
}
struct Payload: Decodable {
  let marker: String
  let listTitle: String?
  let replaceIncompleteMatchingMarker: Bool?
  let items: [Item]
}

struct RuleSummary: Encodable { let frequency: String; let daysOfWeek: [String] }
struct ItemSummary: Encodable {
  let title: String
  let listTitle: String
  let due: String?
  let recurrence: [RuleSummary]
  let alarmsHuman: [String]
}
struct Summary: Encodable {
  let ok: Bool
  let error: String?
  let granted: Bool
  let listTitle: String?
  let listSource: String?
  let removed: Int
  let created: Int
  let expected: Int
  let committed: Bool
  let reminders: [ItemSummary]
}

let gcal = Calendar(identifier: .gregorian)
let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

let encode = { (summary: Summary) -> String in
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return (try? encoder.encode(summary)).flatMap { String(data: $0, encoding: .utf8) }
    ?? "{\"ok\":false,\"error\":\"failed to encode summary\"}"
}
let emit = { (summary: Summary) -> Void in print(encode(summary)) }
let bare = { (ok: Bool, error: String?, granted: Bool) in
  Summary(ok: ok, error: error, granted: granted, listTitle: nil, listSource: nil,
          removed: 0, created: 0, expected: 0, committed: false, reminders: [])
}

// "HH:mm" -> 当日0:00 からの秒数
let clockSeconds = { (s: String) -> Int in
  let parts = s.split(separator: ":").map { Int($0) ?? 0 }
  return (parts.first ?? 0) * 3600 + (parts.count > 1 ? parts[1] : 0) * 60
}

// 今日以降(今日含む)の最初の発生日(0:00基準)。recurrence の dtstart になる。
let nextOccurrence = { (rec: Recurrence) -> Date? in
  let anchor = gcal.startOfDay(for: Date()).addingTimeInterval(-1)
  let first = { (comps: DateComponents) -> Date? in
    gcal.nextDate(after: anchor, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents)
  }
  return rec.freq == "weekly"
    ? (rec.weekdays ?? []).compactMap { first(DateComponents(weekday: $0)) }.min()
    : rec.freq == "monthly"
    ? (rec.monthlyWeekdays ?? []).compactMap { first(DateComponents(weekday: $0.day, weekdayOrdinal: $0.week)) }.min()
    : nil
}

let buildRule = { (rec: Recurrence) -> EKRecurrenceRule? in
  rec.freq == "weekly"
    ? rec.weekdays.map { ws in
        EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
          daysOfTheWeek: ws.compactMap { EKWeekday(rawValue: $0) }.map { EKRecurrenceDayOfWeek($0) },
          daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
      }
    : rec.freq == "monthly"
    ? rec.monthlyWeekdays.map { specs in
        EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
          daysOfTheWeek: specs.compactMap { s in EKWeekday(rawValue: s.day).map { EKRecurrenceDayOfWeek($0, weekNumber: s.week) } },
          daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
      }
    : nil
}

// dueClock があれば [.year..minute]（時刻入り）、無ければ日付のみ。
let dueComponents = { (item: Item, base: Date) -> DateComponents in
  item.dueClock.map { clk -> DateComponents in
    let sec = clockSeconds(clk)
    let withTime = gcal.date(bySettingHour: sec / 3600, minute: (sec % 3600) / 60, second: 0, of: base) ?? base
    return gcal.dateComponents([.year, .month, .day, .hour, .minute], from: withTime)
  } ?? gcal.dateComponents([.year, .month, .day], from: base)
}

let dueStr: (DateComponents?) -> String? = { comps in
  comps.flatMap { c -> String? in
    gcal.date(from: c).map { d in
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
      f.dateFormat = c.hour != nil ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
      return f.string(from: d)
    }
  }
}

let summarizeRule = { (rule: EKRecurrenceRule) -> RuleSummary in
  RuleSummary(
    frequency: rule.frequency == .weekly ? "weekly" : rule.frequency == .monthly ? "monthly" : "other",
    daysOfWeek: (rule.daysOfTheWeek ?? []).map { d in
      let name = weekdayNames[safe: d.dayOfTheWeek.rawValue] ?? "?"
      return d.weekNumber == 0 ? name : "\(name)#\(d.weekNumber)"
    })
}
let offsetHuman = { (sec: Double) -> String in
  let days = Int((-sec / 86400).rounded(.up))
  let remain = Int(sec) + days * 86400
  return String(format: "収集日の%d日前 %02d:%02d", days, remain / 3600, (remain % 3600) / 60)
}
let summarizeReminder = { (r: EKReminder) -> ItemSummary in
  ItemSummary(
    title: r.title ?? "",
    listTitle: r.calendar.title,
    due: dueStr(r.dueDateComponents),
    recurrence: (r.recurrenceRules ?? []).map(summarizeRule),
    alarmsHuman: (r.alarms ?? []).map { offsetHuman($0.relativeOffset) })
}

let run = { (payload: Payload) -> Int32 in
  let store = EKEventStore()
  let requestDone = DispatchSemaphore(value: 0)
  let saveDone = DispatchSemaphore(value: 0)

  let iCloudSource = { () -> EKSource? in
    store.sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" }
      ?? store.calendars(for: .reminder).first { $0.source.sourceType == .calDAV }?.source
      ?? store.defaultCalendarForNewReminders()?.source
  }
  let resolveList = { () -> EKCalendar? in
    payload.listTitle.flatMap { title in
      store.calendars(for: .reminder).first { $0.title == title }
        ?? iCloudSource().flatMap { src -> EKCalendar? in
          let cal = EKCalendar(for: .reminder, eventStore: store)
          cal.title = title; cal.source = src
          return (try? store.saveCalendar(cal, commit: true)).map { cal }
        }
    } ?? store.defaultCalendarForNewReminders() ?? store.calendars(for: .reminder).first
  }

  let verify = { (list: EKCalendar, removed: Int, created: Int, committed: Bool) -> Void in
    store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { reminders in
      let matching = (reminders ?? []).filter { ($0.notes ?? "").contains(payload.marker) }.map(summarizeReminder)
      emit(Summary(
        ok: committed && created == payload.items.count,
        error: committed ? nil : "EventKit commit failed",
        granted: true, listTitle: list.title, listSource: list.source.title,
        removed: removed, created: created, expected: payload.items.count, committed: committed, reminders: matching))
      saveDone.signal()
    }
  }

  let save = { () -> Void in
    resolveList().map { list in
      store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { existing in
        let removed = (payload.replaceIncompleteMatchingMarker ?? true)
          ? (existing ?? []).filter { ($0.notes ?? "").contains(payload.marker) }
              .map { (try? store.remove($0, commit: false)).map { 1 } ?? 0 }.reduce(0, +)
          : 0
        let created = payload.items.map { item -> Int in
          buildRule(item.recurrence).flatMap { rule -> Int? in
            nextOccurrence(item.recurrence).map { base -> Int in
              let r = EKReminder(eventStore: store)
              r.calendar = list
              r.title = item.title
              r.notes = "\(item.notes)\n\n\(payload.marker)"
              r.dueDateComponents = dueComponents(item, base)
              r.addRecurrenceRule(rule)
              _ = item.alarm.map { a in r.addAlarm(EKAlarm(relativeOffset: Double(a.dayOffset * 86400 + clockSeconds(a.clock)))) }
              return (try? store.save(r, commit: false)).map { 1 } ?? 0
            }
          } ?? 0
        }.reduce(0, +)
        let committed = (try? store.commit()).map { true } ?? false
        verify(list, removed, created, committed)
      }
    } ?? { emit(bare(false, "No writable Reminders list found", true)); saveDone.signal() }()
  }

  let requestAccess = { (completion: @escaping (Bool, Error?) -> Void) -> Void in
    if #available(macOS 14.0, *) { store.requestFullAccessToReminders(completion: completion) }
    else { store.requestAccess(to: .reminder, completion: completion) }
  }
  requestAccess { granted, error in
    granted ? save() : { emit(bare(false, error?.localizedDescription ?? "Reminders access was not granted", false)); saveDone.signal() }()
    requestDone.signal()
  }
  requestDone.wait(); saveDone.wait()
  return 0
}

extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }

let input = FileHandle.standardInput.readDataToEndOfFile()
let exitCode = (try? JSONDecoder().decode(Payload.self, from: input)).map(run) ?? {
  emit(bare(false, "Invalid JSON payload", false)); return 2
}()
exit(exitCode)
