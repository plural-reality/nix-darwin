// apply.swift — Apple カレンダーへのイベント書込みの唯一の IO 境界（汎用プリミティブ）。
// f(汎用イベントJSON) -> Apple Calendar の副作用。呼び出し側(消費者)はこの抽象だけに依存する。
//
// この層が知っている「正しさ」:
//   1. iCloud(CalDAV)ソースに作る/書く（On My Mac=iPhone非同期の罠を回避）
//   2. 位置情報を必ず構造化（住所→Apple geocoder→EKStructuredLocation.geoLocation = iPhoneタップでマップ）
//   3. 時刻指定（終日にしない）
//   4. mode で洗い替え(replace-month / replace-range) か 追記(append)
//
// usage: swift apply.swift <events.json>   |   cat events.json | swift apply.swift -
//
// JSON:
// { "calendar": "目黒区民プール",
//   "mode": "replace-month",            // replace-month | replace-range | append
//   "year": 2026, "month": 6,           // replace-month の削除窓
//   "rangeStart": "2026-06-01T00:00", "rangeEnd": "2026-07-01T00:00",  // replace-range の削除窓
//   "defaultLocation": { "title": "...", "address": "東京都…", "lat": 35.6, "lon": 139.7 }, // lat/lon省略可→geocode
//   "events": [
//     { "title": "…", "start": "2026-06-07T18:00", "end": "2026-06-07T22:00",
//       "notes": "…", "url": "https://…",
//       "location": { "title": "…", "address": "…", "lat": …, "lon": … } } ] }  // 省略時 defaultLocation
import EventKit
import Foundation
import CoreLocation

struct Loc: Codable { let title: String?; let address: String?; let lat: Double?; let lon: Double? }
struct Ev: Codable { let title: String; let start: String; let end: String; let notes: String?; let url: String?; let location: Loc?; let alarms: [Int]? }  // alarms = start からの「分前」リスト
struct Sched: Codable {
    let calendar: String
    let mode: String?
    let year: Int?; let month: Int?
    let rangeStart: String?; let rangeEnd: String?
    let defaultLocation: Loc?
    let events: [Ev]
}

func die(_ msg: String, _ code: Int32) -> Never { FileHandle.standardError.write((msg + "\n").data(using: .utf8)!); exit(code) }

// --- input ---
guard CommandLine.arguments.count >= 2 else { die("usage: apply.swift <events.json|->", 64) }
let arg = CommandLine.arguments[1]
let inputData: Data
if arg == "-" {
    inputData = FileHandle.standardInput.readDataToEndOfFile()
} else {
    guard let d = try? Data(contentsOf: URL(fileURLWithPath: arg)) else { die("cannot read \(arg)", 66) }
    inputData = d
}
guard let sched = try? JSONDecoder().decode(Sched.self, from: inputData) else { die("bad JSON", 65) }

// --- datetime ---
let dfMin: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd'T'HH:mm"; return f }()
let dfSec: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"; return f }()
func parseDate(_ s: String) -> Date {
    if let d = dfMin.date(from: s) ?? dfSec.date(from: s) { return d }
    die("bad datetime: \(s) (expect yyyy-MM-ddTHH:mm)", 67)
}

// --- geocode cache (CLGeocoder は main queue コールバック → RunLoop で待つ) ---
var geoCache: [String: CLLocation?] = [:]
func geocode(_ address: String) -> CLLocation? {
    if let cached = geoCache[address] { return cached }
    var result: CLLocation? = nil
    var done = false
    CLGeocoder().geocodeAddressString(address) { placemarks, _ in result = placemarks?.first?.location; done = true }
    let deadline = Date(timeIntervalSinceNow: 15)
    while !done && Date() < deadline { RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1)) }
    geoCache[address] = result
    return result
}

// --- EventKit access ---
let store = EKEventStore()
let sema = DispatchSemaphore(value: 0)
var granted = false
if #available(macOS 14.0, *) { store.requestFullAccessToEvents { ok, _ in granted = ok; sema.signal() } }
else { store.requestAccess(to: .event) { ok, _ in granted = ok; sema.signal() } }
_ = sema.wait(timeout: .now() + 30)
guard granted else { die("DENIED calendar access", 1) }

// --- calendar (必ず iCloud) ---
func iCloudSource() -> EKSource? {
    store.sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" }
        ?? store.calendars(for: .event).first { $0.source.sourceType == .calDAV }?.source
        ?? store.sources.first { $0.sourceType == .calDAV }
}
func resolveCalendar() -> EKCalendar {
    if let c = store.calendars(for: .event).first(where: { $0.title == sched.calendar && $0.source.sourceType == .calDAV }) { return c }
    if let c = store.calendars(for: .event).first(where: { $0.title == sched.calendar }) { return c }
    guard let src = iCloudSource() else { die("no iCloud source", 2) }
    let cal = EKCalendar(for: .event, eventStore: store)
    cal.title = sched.calendar; cal.source = src
    do { try store.saveCalendar(cal, commit: true) } catch { die("create calendar failed: \(error)", 3) }
    return cal
}
let cal = resolveCalendar()

// --- 構造化位置 (event.location ?? defaultLocation) ---
func structured(for loc: Loc?) -> (EKStructuredLocation?, String?)? {
    guard let l = loc else { return nil }
    let coord: CLLocation? = (l.lat != nil && l.lon != nil) ? CLLocation(latitude: l.lat!, longitude: l.lon!)
        : (l.address.flatMap { geocode($0) })
    let title = l.title ?? l.address ?? "場所"
    let sl = EKStructuredLocation(title: title)
    if let c = coord { sl.geoLocation = c }
    let str: String = {
        if let t = l.title, let a = l.address { return "\(t)（\(a)）" }
        return l.title ?? l.address ?? title
    }()
    return (sl, str)
}

// --- 削除窓 (洗い替え) ---
let mode = sched.mode ?? ((sched.year != nil && sched.month != nil) ? "replace-month" : "append")
let gcal = Calendar(identifier: .gregorian)
var delStart: Date? = nil, delEnd: Date? = nil
switch mode {
case "replace-month":
    guard let y = sched.year, let m = sched.month else { die("replace-month needs year/month", 68) }
    delStart = gcal.date(from: DateComponents(year: y, month: m, day: 1))
    delEnd = delStart.flatMap { gcal.date(byAdding: .month, value: 1, to: $0) }
case "replace-range":
    guard let s = sched.rangeStart, let e = sched.rangeEnd else { die("replace-range needs rangeStart/rangeEnd", 68) }
    delStart = parseDate(s); delEnd = parseDate(e)
case "append": break
default: die("unknown mode: \(mode)", 68)
}
var removed = 0
if let s = delStart, let e = delEnd {
    let old = store.events(matching: store.predicateForEvents(withStart: s, end: e, calendars: [cal]))
    for ev in old { try? store.remove(ev, span: .thisEvent, commit: false); removed += 1 }
}

// --- 投入 ---
var n = 0
for ev in sched.events {
    let e = EKEvent(eventStore: store)
    e.calendar = cal
    e.title = ev.title
    e.startDate = parseDate(ev.start)
    e.endDate = parseDate(ev.end)
    if let notes = ev.notes { e.notes = notes }
    if let u = ev.url, let url = URL(string: u) { e.url = url }
    for m in (ev.alarms ?? []) { e.addAlarm(EKAlarm(relativeOffset: -Double(m) * 60)) }  // m 分前に通知
    if let (sl, str) = structured(for: ev.location ?? sched.defaultLocation) {
        e.location = str
        if let sl = sl { e.structuredLocation = sl }
    }
    do { try store.save(e, span: .thisEvent, commit: false); n += 1 }
    catch { die("save failed (\(ev.title)): \(error)", 4) }
}
do { try store.commit() } catch { die("commit failed: \(error)", 5) }
print("applied \(n) / removed \(removed) / mode=\(mode) / cal='\(sched.calendar)' source=\(cal.source.title)")
