#!/usr/bin/env swift
// complete.swift — Apple リマインダーの完了状態を変更する唯一の IO 境界。
//
// f(spec JSON on stdin) -> iCloud Reminders 副作用 -> 検証 JSON on stdout。
// 直接 swift で叩かず、署名済み evkitd からのみ呼び出す。
//
// spec:
// {"ids":["..."],"titles":["完全一致タイトル"],"listTitle":"多元タスク","completed":true}
// ids または titles の少なくとも一方を必須とし、タイトルは完全一致だけにする。

import EventKit
import Foundation

struct Payload: Decodable {
    let ids: [String]
    let titles: [String]
    let listTitle: String?
    let completed: Bool

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ids = try values.decodeIfPresent([String].self, forKey: .ids) ?? []
        titles = try values.decodeIfPresent([String].self, forKey: .titles) ?? []
        listTitle = try values.decodeIfPresent(String.self, forKey: .listTitle)
        completed = try values.decodeIfPresent(Bool.self, forKey: .completed) ?? true
    }

    enum CodingKeys: String, CodingKey { case ids, titles, listTitle, completed }
}

struct ReminderSummary: Encodable {
    let id: String
    let title: String
    let listTitle: String
    let completed: Bool
}

struct Summary: Encodable {
    let ok: Bool
    let error: String?
    let granted: Bool
    let requested: Int
    let matched: Int
    let changed: Int
    let committed: Bool
    let reminders: [ReminderSummary]
}

let emit = { (summary: Summary) -> Void in
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = (try? encoder.encode(summary)) ?? Data(#"{"ok":false,"error":"failed to encode summary"}"#.utf8)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

let input = FileHandle.standardInput.readDataToEndOfFile()
let payload = try? JSONDecoder().decode(Payload.self, from: input)
guard let payload else {
    emit(Summary(ok: false, error: "Invalid JSON payload", granted: false,
                 requested: 0, matched: 0, changed: 0, committed: false, reminders: []))
    exit(2)
}

let requestedIDs = Set(payload.ids)
let requestedTitles = Set(payload.titles)
guard !requestedIDs.isEmpty || !requestedTitles.isEmpty else {
    emit(Summary(ok: false, error: "ids または titles が必要です", granted: true,
                 requested: 0, matched: 0, changed: 0, committed: false, reminders: []))
    exit(64)
}

let store = EKEventStore()
guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
    emit(Summary(ok: false, error: "Reminders access was not granted; run evkit seed on the MacBook Air",
                 granted: false, requested: requestedIDs.count + requestedTitles.count,
                 matched: 0, changed: 0, committed: false, reminders: []))
    exit(1)
}

let lists = store.calendars(for: .reminder).filter { calendar in
    payload.listTitle.map { calendar.title == $0 } ?? true
}
guard !lists.isEmpty else {
    emit(Summary(ok: false, error: "指定されたリストが見つかりません", granted: true,
                 requested: requestedIDs.count + requestedTitles.count,
                 matched: 0, changed: 0, committed: false, reminders: []))
    exit(1)
}

let done = DispatchSemaphore(value: 0)
let predicate = store.predicateForReminders(in: lists)
let fetch = { (completion: @escaping ([EKReminder]) -> Void) -> Void in
    store.fetchReminders(matching: predicate) { reminders in
        completion(reminders ?? [])
    }
}

fetch { reminders in
    let idMatches = reminders.filter { requestedIDs.contains($0.calendarItemIdentifier) }
    let titleMatches = reminders.filter { requestedTitles.contains($0.title ?? "") }
    let matching = reminders.filter {
        requestedIDs.contains($0.calendarItemIdentifier) || requestedTitles.contains($0.title ?? "")
    }
    let idsCovered = requestedIDs.allSatisfy { id in
        idMatches.contains { $0.calendarItemIdentifier == id }
    }
    let titlesCovered = requestedTitles.allSatisfy { title in
        titleMatches.contains { ($0.title ?? "") == title }
    }
    let selectorsCovered = idsCovered && titlesCovered
    let summaries = { (values: [EKReminder]) in
        values.map { reminder in
            ReminderSummary(id: reminder.calendarItemIdentifier,
                            title: reminder.title ?? "",
                            listTitle: reminder.calendar.title,
                            completed: reminder.isCompleted)
        }
    }

    guard selectorsCovered else {
        emit(Summary(ok: false,
                     error: "指定されたIDまたはタイトルの全件を確認できないため変更しません",
                     granted: true,
                     requested: requestedIDs.count + requestedTitles.count,
                     matched: matching.count,
                     changed: 0,
                     committed: false,
                     reminders: summaries(matching)))
        done.signal()
        return
    }

    let changed = matching.filter { $0.isCompleted != payload.completed }
    let saveResults = changed.map { reminder -> Bool in
        reminder.isCompleted = payload.completed
        return (try? store.save(reminder, commit: false)).map { _ in true } ?? false
    }
    let committed = changed.isEmpty
        || (saveResults.allSatisfy { $0 } && ((try? store.commit()).map { _ in true } ?? false))

    guard committed else {
        emit(Summary(ok: false,
                     error: "EventKit commit failed",
                     granted: true,
                     requested: requestedIDs.count + requestedTitles.count,
                     matched: matching.count,
                     changed: changed.count,
                     committed: false,
                     reminders: summaries(matching)))
        done.signal()
        return
    }

    fetch { reread in
        let rereadMatching = reread.filter {
            requestedIDs.contains($0.calendarItemIdentifier) || requestedTitles.contains($0.title ?? "")
        }
        let readbackOK = rereadMatching.count == matching.count
            && rereadMatching.allSatisfy { $0.isCompleted == payload.completed }
        emit(Summary(ok: readbackOK,
                     error: readbackOK ? nil : "保存後の再読込で完了状態を確認できないため失敗扱いにします",
                     granted: true,
                     requested: requestedIDs.count + requestedTitles.count,
                     matched: rereadMatching.count,
                     changed: changed.count,
                     committed: true,
                     reminders: summaries(rereadMatching)))
        done.signal()
        return
    }
}
done.wait()
