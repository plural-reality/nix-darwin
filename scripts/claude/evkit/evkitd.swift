// evkitd.swift — Apple カレンダー/リマインダー(EventKit)への副作用に対する唯一の TCC アンカー。
//
//   f(request JSON on stdin) -> response JSON on stdout
//
// launchd の inetdCompatibility により、stdin/stdout はそのまま unix domain socket に繋がる。
// つまりこのプロセスは純粋な「ストリーム変換器」であり、ソケットも accept(2) も知らない。
//
// なぜ存在するか(= このバイナリが解いている唯一の問題):
//   macOS の TCC は「責任プロセス(responsible process)の code identity」に許可を紐づける。
//   Claude Code から直接 EventKit を叩くと、責任プロセスは
//   /Users/tkgshn/.local/share/claude/versions/<version> になり、**更新のたびに別クライアント**
//   として権限がリセットされる。さらに SSH/tmux は Aqua セッションではないため、そもそも許可
//   ダイアログを描画できず自動拒否される。
//
//   このバイナリは (a) 自己署名証明書で安定した code identity を持ち、
//   (b) LaunchAgent により gui/<uid>(Aqua) で起動されるため、許可を一度だけ受け取り恒久に保持できる。
//
// なぜ既存スクリプトを取り込まないか:
//   TCC の責任プロセスは子プロセスへ継承される。よって evkitd が親として apply.swift 等を
//   exec すれば、その EventKit アクセスは com.tkgshn.evkitbridge に帰属する。
//   結果、カレンダー/リマインダーの「正しさ」の canonical な定義は既存スクリプトに一元化されたまま、
//   このバイナリは権限境界だけを担う。ロジックはここに複製しない。

import EventKit
import Foundation

// op -> (script, args)。固定表以外は実行しない(任意コード実行の窓口にしない)。
let handlers: [String: (script: String, args: [String])] = [
    "calendar": ("/Users/tkgshn/.claude/scripts/calendar/apply.swift", ["-"]),
    "reminders.recurring": ("/Users/tkgshn/.claude/scripts/reminders/recurring.swift", []),
    "reminders.geofence": (
        "/Users/tkgshn/.claude/skills/apple-reminders-geofence/scripts/geofence_reminders.swift", []
    ),
]

let stdoutHandle = FileHandle.standardOutput

func respond(_ obj: [String: Any]) -> Never {
    let data = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]))
        ?? Data(#"{"ok":false,"error":"response encoding failed"}"#.utf8)
    stdoutHandle.write(data)
    stdoutHandle.write(Data("\n".utf8))
    exit(obj["ok"] as? Bool == true ? 0 : 1)
}

func fail(_ message: String, _ extra: [String: Any] = [:]) -> Never {
    respond(extra.merging(["ok": false, "error": message]) { a, _ in a })
}

// --- request ---
// 1接続 = 改行終端の JSON 1行。EOF ではなく改行で切るのは、macOS の nc に
// BSD の -N(EOF で socket を half-close)が無いため。client に shutdown(2) を要求しない。
func readRequestLine() -> Data {
    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = read(0, &chunk, chunk.count)
        if n <= 0 { break }
        buffer.append(contentsOf: chunk[0..<n])
        if let newline = buffer.firstIndex(of: 0x0A) { return Data(buffer[..<newline]) }
    }
    return buffer
}

guard
    let request = (try? JSONSerialization.jsonObject(with: readRequestLine())) as? [String: Any],
    let op = request["op"] as? String
else { fail("bad request JSON (expect a single line {\"op\":…})") }

// --- TCC: このプロセスの identity で許可を確定させる ---
// notDetermined のときだけプロンプトが出る。Aqua セッションなので描画できる。
// 許可が付いた後は、子プロセス(apply.swift 等)の EventKit アクセスもこの identity に帰属する。
let store = EKEventStore()

func ensureAccess() -> (event: Int, reminder: Int) {
    func request(_ requester: (@escaping (Bool, Error?) -> Void) -> Void) {
        let sema = DispatchSemaphore(value: 0)
        requester { _, _ in sema.signal() }
        _ = sema.wait(timeout: .now() + 180)  // GUI でユーザーがクリックするのを待つ
    }
    if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
        request { store.requestFullAccessToEvents(completion: $0) }
    }
    if EKEventStore.authorizationStatus(for: .reminder) != .fullAccess {
        request { store.requestFullAccessToReminders(completion: $0) }
    }
    return (
        EKEventStore.authorizationStatus(for: .event).rawValue,
        EKEventStore.authorizationStatus(for: .reminder).rawValue
    )
}

let status = ensureAccess()
// 0=notDetermined 1=restricted 2=denied 3=fullAccess 4=writeOnly
let statusJSON: [String: Any] = ["event": status.event, "reminder": status.reminder]

// status / seed: 許可の確認と、初回プロンプトの発火だけを行う。
if op == "status" || op == "seed" {
    respond([
        "ok": status.event == 3 && status.reminder == 3,
        "status": statusJSON,
        "bundleID": Bundle.main.bundleIdentifier ?? "(none)",
    ])
}

guard let handler = handlers[op] else {
    fail("unknown op: \(op)", ["ops": Array(handlers.keys).sorted() + ["status", "seed"]])
}

// カレンダーは event、リマインダーは reminder の fullAccess が要る。
let needsEvent = op == "calendar"
if needsEvent && status.event != 3 {
    fail(
        "calendar access not granted (status=\(status.event)). "
            + "システム設定 → プライバシーとセキュリティ → カレンダー → EventKitBridge をフルアクセスにしてください。",
        ["status": statusJSON])
}
if !needsEvent && status.reminder != 3 {
    fail(
        "reminders access not granted (status=\(status.reminder)). "
            + "システム設定 → プライバシーとセキュリティ → リマインダー → EventKitBridge を有効にしてください。",
        ["status": statusJSON])
}

guard let spec = request["spec"], JSONSerialization.isValidJSONObject(spec) || spec is [Any] else {
    fail("op \(op) requires a \"spec\" object")
}
guard let specData = try? JSONSerialization.data(withJSONObject: spec) else {
    fail("spec is not encodable JSON")
}

// --- 子プロセスへ委譲 ---
// stdout/stderr はパイプではなく一時ファイルで受ける(パイプバッファ枯渇によるデッドロックを避ける)。
// ponytail: 出力は高々数十KB。ストリーミングが要るサイズになったら Pipe + 並行読み出しへ。
let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("evkitd-\(getpid())", isDirectory: true)
try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: scratch) }

let outURL = scratch.appendingPathComponent("out")
let errURL = scratch.appendingPathComponent("err")
let inURL = scratch.appendingPathComponent("in")
guard (try? specData.write(to: inURL)) != nil,
    FileManager.default.createFile(atPath: outURL.path, contents: nil),
    FileManager.default.createFile(atPath: errURL.path, contents: nil),
    let inFH = try? FileHandle(forReadingFrom: inURL),
    let outFH = try? FileHandle(forWritingTo: outURL),
    let errFH = try? FileHandle(forWritingTo: errURL)
else { fail("cannot stage scratch files") }

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
task.arguments = [handler.script] + handler.args
task.standardInput = inFH
task.standardOutput = outFH
task.standardError = errFH

do { try task.run() } catch { fail("cannot spawn \(handler.script): \(error)") }
task.waitUntilExit()

let childOut = (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
let childErr = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""

respond([
    "ok": task.terminationStatus == 0,
    "op": op,
    "exit": Int(task.terminationStatus),
    "stdout": childOut,
    "stderr": childErr,
    "status": statusJSON,
])
