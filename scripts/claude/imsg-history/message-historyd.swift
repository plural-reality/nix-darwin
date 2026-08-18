// message-historyd.swift — read-only iMessage history behind one stable TCC identity.
//
// Pure transformations (request validation, typedstream decoding, value
// projection) are kept separate from the SQLite and stdio boundary. The
// database accepts no caller-provided SQL and is always opened read-only.

import Foundation
import CSQLite

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DecodeStatus: String, Codable {
    case legacy
    case typedstreamHeuristic = "typedstream_heuristic"
    case attachmentOnly = "attachment_only"
    case missing
    case unsupported
}

struct MessageRecord: Codable, Equatable {
    let rowID: Int64
    let guid: String
    let dateRaw: Int64
    let date: String?
    let direction: String
    let sender: String?
    let service: String?
    let chatRowID: Int64
    let chatGUID: String?
    let chatName: String?
    let participants: [String]
    let text: String?
    let decodeStatus: DecodeStatus
    let attachmentCount: Int
}

struct ChatRecord: Codable, Equatable {
    let guid: String
    let name: String?
    let participants: [String]
    let lastMessageAt: String?
}

struct MessageCursor: Codable, Equatable {
    let dateRaw: Int64
    let rowID: Int64
    let chatRowID: Int64
}

struct QuerySpec: Decodable, Equatable {
    let limit: Int?
    let query: String?
    let handle: String?
    let chatGUID: String?
    let before: MessageCursor?
}

struct BridgeRequest: Decodable, Equatable {
    let op: String
    let spec: QuerySpec?
}

struct EndRecord: Codable, Equatable {
    let type: String
    let ok: Bool
    let count: Int
    let readable: Bool?
    let error: String?
    let nextCursor: MessageCursor?

    static let success: (Int) -> EndRecord = {
        EndRecord(
            type: "end", ok: true, count: $0,
            readable: nil, error: nil, nextCursor: nil)
    }

    static let page: ([MessageRecord], Int) -> EndRecord = { values, limit in
        EndRecord(
            type: "end",
            ok: true,
            count: values.count,
            readable: nil,
            error: nil,
            nextCursor: values.count == limit
                ? values.first.map {
                    MessageCursor(
                        dateRaw: $0.dateRaw,
                        rowID: $0.rowID,
                        chatRowID: $0.chatRowID)
                }
                : nil)
    }

    static let status: (Bool, String?) -> EndRecord = {
        EndRecord(
            type: "end", ok: $0, count: 0,
            readable: $0, error: $1, nextCursor: nil)
    }

    static let failure: (String) -> EndRecord = {
        EndRecord(
            type: "end", ok: false, count: 0,
            readable: nil, error: $0, nextCursor: nil)
    }
}

struct MessageEnvelope: Codable, Equatable {
    let type: String
    let message: MessageRecord

    init(_ message: MessageRecord) {
        type = "message"
        self.message = message
    }
}

struct ChatEnvelope: Codable, Equatable {
    let type: String
    let chat: ChatRecord

    init(_ chat: ChatRecord) {
        type = "chat"
        self.chat = chat
    }
}

enum BridgeOutput: Encodable, Equatable {
    case message(MessageEnvelope)
    case chat(ChatEnvelope)
    case end(EndRecord)

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .message(value): try value.encode(to: encoder)
        case let .chat(value): try value.encode(to: encoder)
        case let .end(value): try value.encode(to: encoder)
        }
    }
}

enum BridgeFailure: Error, Equatable {
    case invalidRequest(String)
    case databaseUnavailable
    case queryFailed

    var publicMessage: String {
        switch self {
        case let .invalidRequest(message): message
        case .databaseUnavailable:
            "Messages database is unavailable; grant Full Disk Access to MessageHistoryBridge.app"
        case .queryFailed: "Messages database query failed"
        }
    }
}

struct DecodedText: Equatable {
    let text: String?
    let status: DecodeStatus
}

let normalizedText: (String?) -> String? = {
    $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0 : nil
}

let readTypedstreamInteger: ([UInt8], Int) -> (Int, Int)? = { bytes, position in
    guard position < bytes.count else { return nil }
    let marker = bytes[position]
    let widths: [UInt8: Int] = [0x81: 2, 0x82: 4, 0x83: 8]
    return widths[marker].flatMap { width in
        let start = position + 1
        let end = start + width
        return end <= bytes.count
            ? (
                bytes[start..<end].enumerated().reduce(0) { value, pair in
                    value | (Int(pair.element) << (pair.offset * 8))
                },
                end)
            : nil
    } ?? (Int(marker), position + 1)
}

let firstSubsequenceIndex: ([UInt8], [UInt8], Int) -> Int? = { bytes, needle, start in
    guard !needle.isEmpty, start >= 0, start <= bytes.count - needle.count else { return nil }
    return (start...(bytes.count - needle.count)).first {
        Array(bytes[$0..<($0 + needle.count)]) == needle
    }
}

let decodeTypedstream: (Data) -> String? = { data in
    guard data.count <= 8 * 1024 * 1024 else { return nil }
    let bytes = [UInt8](data)
    let nsString = [UInt8]("NSString".utf8)
    return firstSubsequenceIndex(bytes, nsString, 0).flatMap { stringIndex in
        bytes.indices.dropFirst(stringIndex + nsString.count).first { bytes[$0] == 0x2B }
    }.flatMap { markerIndex in
        readTypedstreamInteger(bytes, markerIndex + 1)
    }.flatMap { length, textStart in
        let bounded = length >= 0
            && textStart <= bytes.count
            && length <= bytes.count - textStart
        return bounded
            ? String(data: Data(bytes[textStart..<(textStart + length)]), encoding: .utf8)
            : nil
    }.flatMap(normalizedText)
}

let decodeBody: (String?, Data?, Int) -> DecodedText = { legacy, attributed, attachments in
    normalizedText(legacy).map { DecodedText(text: $0, status: .legacy) }
        ?? attributed.flatMap(decodeTypedstream).map {
            DecodedText(text: $0, status: .typedstreamHeuristic)
        }
        ?? (attachments > 0
            ? DecodedText(text: nil, status: .attachmentOnly)
            : DecodedText(text: nil, status: attributed == nil ? .missing : .unsupported))
}

let appleDate: (Int64) -> String? = { raw in
    guard raw != 0 else { return nil }
    let seconds = abs(raw) > 100_000_000_000 ? Double(raw) / 1_000_000_000 : Double(raw)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date(timeIntervalSinceReferenceDate: seconds))
}

let splitParticipants: (String?) -> [String] = {
    ($0 ?? "").split(separator: "|").map(String.init).filter { !$0.isEmpty }.sorted()
}

func completeBackup(_ backup: OpaquePointer) -> Int32 {
    var result = sqlite3_backup_step(backup, 256)
    // ponytail: a child gets 60 s total for a consistent snapshot; if measured
    // database growth exceeds this ceiling, move backup creation to a supervisor.
    let deadline = ProcessInfo.processInfo.systemUptime + 60.0
    while ProcessInfo.processInfo.systemUptime < deadline
        && (result == SQLITE_OK || [SQLITE_BUSY, SQLITE_LOCKED].contains(result))
    {
        if [SQLITE_BUSY, SQLITE_LOCKED].contains(result) {
            Thread.sleep(forTimeInterval: 0.01)
        }
        result = sqlite3_backup_step(backup, 256)
    }
    return result
}

final class ReadonlyDatabase {
    private let handle: OpaquePointer
    private let cleanupPath: String?

    init(path: String) throws {
        cleanupPath = nil
        handle = try Self.open(path: path)
    }

    private init(path: String, cleanupPath: String) throws {
        self.cleanupPath = cleanupPath
        handle = try Self.open(path: path)
    }

    private static func open(path: String) throws -> OpaquePointer {
        var opened: OpaquePointer?
        let result = sqlite3_open_v2(path, &opened, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard result == SQLITE_OK, let database = opened else {
            _ = opened.map(sqlite3_close)
            throw BridgeFailure.databaseUnavailable
        }
        guard sqlite3_exec(database, "PRAGMA query_only=ON; PRAGMA trusted_schema=OFF;", nil, nil, nil)
            == SQLITE_OK,
            sqlite3_db_readonly(database, "main") == 1
        else {
            sqlite3_close(database)
            throw BridgeFailure.queryFailed
        }
        return database
    }

    static func snapshot(sourcePath: String) throws -> ReadonlyDatabase {
        let source = try ReadonlyDatabase(path: sourcePath)
        let snapshotPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("imsg-history-\(UUID().uuidString).sqlite").path
        guard FileManager.default.createFile(
            atPath: snapshotPath,
            contents: nil,
            attributes: [.posixPermissions: 0o600])
        else { throw BridgeFailure.queryFailed }
        var destination: OpaquePointer?
        guard sqlite3_open_v2(
            snapshotPath,
            &destination,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX,
            nil) == SQLITE_OK,
            let target = destination
        else {
            _ = destination.map(sqlite3_close)
            try? FileManager.default.removeItem(atPath: snapshotPath)
            throw BridgeFailure.queryFailed
        }
        let backup = sqlite3_backup_init(target, "main", source.handle, "main")
        let result = backup.map { completeBackup($0) } ?? SQLITE_ERROR
        _ = backup.map(sqlite3_backup_finish)
        sqlite3_close(target)
        guard result == SQLITE_DONE else {
            try? FileManager.default.removeItem(atPath: snapshotPath)
            throw BridgeFailure.queryFailed
        }
        do {
            return try ReadonlyDatabase(path: snapshotPath, cleanupPath: snapshotPath)
        } catch {
            try? FileManager.default.removeItem(atPath: snapshotPath)
            throw error
        }
    }

    deinit {
        sqlite3_close(handle)
        cleanupPath.map { try? FileManager.default.removeItem(atPath: $0) }
    }

    func prepare(_ sql: String, bindings: [String] = []) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let prepared = statement
        else { throw BridgeFailure.queryFailed }
        let bindingSucceeded = bindings.enumerated().allSatisfy { index, value in
            sqlite3_bind_text(prepared, Int32(index + 1), value, -1, sqliteTransient) == SQLITE_OK
        }
        guard bindingSucceeded else {
            sqlite3_finalize(prepared)
            throw BridgeFailure.queryFailed
        }
        return prepared
    }

    func isReadable() -> Bool {
        (try? prepare("SELECT 1 FROM message LIMIT 1")).map { statement in
            defer { sqlite3_finalize(statement) }
            return [SQLITE_ROW, SQLITE_DONE].contains(sqlite3_step(statement))
        } ?? false
    }
}

let sqliteString: (OpaquePointer, Int32) -> String? = { statement, column in
    sqlite3_column_text(statement, column).map { String(cString: $0) }
}

let sqliteData: (OpaquePointer, Int32, Int) -> Data? = { statement, column, maximumBytes in
    let length = Int(sqlite3_column_bytes(statement, column))
    return length > 0 && length <= maximumBytes
        ? sqlite3_column_blob(statement, column).map { Data(bytes: $0, count: length) }
        : nil
}

let messageFromRow: (OpaquePointer) -> MessageRecord = { statement in
    let attachmentCount = Int(sqlite3_column_int(statement, 11))
    let attributedLength = Int(sqlite3_column_bytes(statement, 6))
    let attributed = sqliteData(statement, 6, 8 * 1024 * 1024)
    let decoded = attributedLength > 8 * 1024 * 1024
        ? DecodedText(text: nil, status: .unsupported)
        : decodeBody(sqliteString(statement, 5), attributed, attachmentCount)
    return MessageRecord(
        rowID: sqlite3_column_int64(statement, 0),
        guid: sqliteString(statement, 1) ?? "",
        dateRaw: sqlite3_column_int64(statement, 2),
        date: appleDate(sqlite3_column_int64(statement, 2)),
        direction: sqlite3_column_int(statement, 3) == 1 ? "me" : "them",
        sender: sqliteString(statement, 4),
        service: sqliteString(statement, 7),
        chatRowID: sqlite3_column_int64(statement, 8),
        chatGUID: sqliteString(statement, 9),
        chatName: sqliteString(statement, 10),
        participants: splitParticipants(sqliteString(statement, 12)),
        text: decoded.text,
        decodeStatus: decoded.status,
        attachmentCount: attachmentCount)
}

let messageSelect = """
SELECT m.ROWID,
       COALESCE(m.guid, ''),
       COALESCE(m.date, 0),
       m.is_from_me,
       h.id,
       m.text,
       m.attributedBody,
       m.service,
       c.ROWID,
       c.guid,
       c.display_name,
       (SELECT COUNT(*) FROM message_attachment_join maj WHERE maj.message_id = m.ROWID),
       (SELECT GROUP_CONCAT(member.id, '|')
          FROM (
            SELECT participant.id AS id
              FROM chat_handle_join chj
              JOIN handle participant ON participant.ROWID = chj.handle_id
             WHERE chj.chat_id = c.ROWID
             ORDER BY participant.id) member)
  FROM chat_message_join membership
  JOIN message m ON m.ROWID = membership.message_id
  JOIN chat c ON c.ROWID = membership.chat_id
  LEFT JOIN handle h ON h.ROWID = m.handle_id
"""

let validatedLimit: (Int?) -> Result<Int, BridgeFailure> = {
    let value = $0 ?? 20
    return (1...1000).contains(value)
        ? .success(value)
        : .failure(.invalidRequest("limit must be between 1 and 1000"))
}

let beforeClause: (MessageCursor?, Bool) -> String = { cursor, hasPredicate in
    cursor.map {
        "\(hasPredicate ? " AND" : " WHERE") "
            + "(COALESCE(m.date, 0) < \($0.dateRaw) OR (COALESCE(m.date, 0) = \($0.dateRaw) AND "
            + "(m.ROWID < \($0.rowID) OR (m.ROWID = \($0.rowID) AND c.ROWID < \($0.chatRowID)))))"
    } ?? ""
}

func rows(
    database: ReadonlyDatabase,
    sql: String,
    bindings: [String],
    limit: Int,
    predicate: (MessageRecord) -> Bool = { _ in true }
) throws -> [MessageRecord] {
    let statement = try database.prepare(sql, bindings: bindings)
    defer { sqlite3_finalize(statement) }
    var values: [MessageRecord] = []
    var step = sqlite3_step(statement)
    while step == SQLITE_ROW && values.count < limit {
        let value = messageFromRow(statement)
        values = predicate(value) ? values + [value] : values
        step = sqlite3_step(statement)
    }
    guard [SQLITE_ROW, SQLITE_DONE].contains(step) || values.count == limit else {
        throw BridgeFailure.queryFailed
    }
    return values
}

func queryMessages(database: ReadonlyDatabase, request: BridgeRequest) throws -> [MessageRecord] {
    let limit = try validatedLimit(request.spec?.limit).get()
    return switch request.op {
    case "recent":
        try rows(
            database: database,
            sql: messageSelect + beforeClause(request.spec?.before, false)
                + " ORDER BY COALESCE(m.date, 0) DESC, m.ROWID DESC, c.ROWID DESC LIMIT \(limit)",
            bindings: [],
            limit: limit).reversed()
    case "search":
        // ponytail: attributedBody requires a bounded newest-first O(n) scan;
        // add a maintained FTS index only if measured rare-query latency warrants it.
        try request.spec?.query.flatMap(normalizedText).map { query in
            try rows(
                database: database,
                sql: messageSelect + beforeClause(request.spec?.before, false)
                    + " ORDER BY COALESCE(m.date, 0) DESC, m.ROWID DESC, c.ROWID DESC",
                bindings: [],
                limit: limit,
                predicate: { $0.text?.localizedCaseInsensitiveContains(query) == true }).reversed()
        } ?? { throw BridgeFailure.invalidRequest("search requires a non-empty query") }()
    case "chat":
        try request.spec?.chatGUID.flatMap(normalizedText).map { chatGUID in
            try rows(
                database: database,
                sql: messageSelect + """
                 WHERE c.guid = ?
                \(beforeClause(request.spec?.before, true))
                 ORDER BY COALESCE(m.date, 0) DESC, m.ROWID DESC, c.ROWID DESC LIMIT \(limit)
                """,
                bindings: [chatGUID],
                limit: limit).reversed()
        } ?? { throw BridgeFailure.invalidRequest("chat requires a chatGUID") }()
    case "with":
        // The direct thread only: a chat whose sole participant is the handle.
        // Chat membership alone would also match every group the handle is in,
        // returning third parties' messages as if they were this conversation.
        try request.spec?.handle.flatMap(normalizedText).map { handle in
            try rows(
                database: database,
                sql: messageSelect + """
                 WHERE c.ROWID IN (
                   SELECT members.chat_id
                     FROM chat_handle_join members
                     JOIN handle participant ON participant.ROWID = members.handle_id
                    GROUP BY members.chat_id
                   HAVING COUNT(DISTINCT members.handle_id) = 1 AND MAX(participant.id) = ?)
                \(beforeClause(request.spec?.before, true))
                 ORDER BY COALESCE(m.date, 0) DESC, m.ROWID DESC, c.ROWID DESC LIMIT \(limit)
                """,
                bindings: [handle],
                limit: limit).reversed()
        } ?? { throw BridgeFailure.invalidRequest("with requires a handle") }()
    default: throw BridgeFailure.invalidRequest("unsupported message operation")
    }
}

func queryChats(database: ReadonlyDatabase, request: BridgeRequest) throws -> [ChatRecord] {
    let limit = try validatedLimit(request.spec?.limit).get()
    let query = request.spec?.query.flatMap(normalizedText)
    let predicate = query.map { _ in " HAVING c.display_name LIKE ? OR participants LIKE ?" } ?? ""
    let bindings = query.map { ["%\($0)%", "%\($0)%"] } ?? []
    let statement = try database.prepare("""
        SELECT c.guid,
               c.display_name,
               GROUP_CONCAT(DISTINCT h.id) AS participants,
               MAX(m.date) AS last_date
          FROM chat c
          LEFT JOIN chat_handle_join chj ON chj.chat_id = c.ROWID
          LEFT JOIN handle h ON h.ROWID = chj.handle_id
          LEFT JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
          LEFT JOIN message m ON m.ROWID = cmj.message_id
         GROUP BY c.ROWID
        \(predicate)
         ORDER BY last_date DESC, c.ROWID DESC
         LIMIT \(limit)
        """, bindings: bindings)
    defer { sqlite3_finalize(statement) }
    var values: [ChatRecord] = []
    var step = sqlite3_step(statement)
    while step == SQLITE_ROW {
        values = values + [ChatRecord(
            guid: sqliteString(statement, 0) ?? "",
            name: sqliteString(statement, 1).flatMap(normalizedText),
            participants: splitParticipants(sqliteString(statement, 2)?.replacingOccurrences(of: ",", with: "|")),
            lastMessageAt: appleDate(sqlite3_column_int64(statement, 3)))]
        step = sqlite3_step(statement)
    }
    guard step == SQLITE_DONE else { throw BridgeFailure.queryFailed }
    return values
}

let messageOutputs: (ReadonlyDatabase, BridgeRequest) throws -> [BridgeOutput] = { database, request in
    let limit = try validatedLimit(request.spec?.limit).get()
    let values = try queryMessages(database: database, request: request)
    return values.map { .message(MessageEnvelope($0)) } + [.end(.page(values, limit))]
}

let chatOutputs: (ReadonlyDatabase, BridgeRequest) throws -> [BridgeOutput] = { database, request in
    let values = try queryChats(database: database, request: request)
    return values.map { .chat(ChatEnvelope($0)) } + [.end(.success(values.count))]
}

let execute: (BridgeRequest, String) -> [BridgeOutput] = { request, databasePath in
    do {
        let database = try (request.op == "search"
            ? ReadonlyDatabase.snapshot(sourcePath: databasePath)
            : ReadonlyDatabase(path: databasePath))
        return switch request.op {
        case "status": {
            let readable = database.isReadable()
            return [.end(.status(readable, readable ? nil : "database query failed"))]
        }()
        case "chats": try chatOutputs(database, request)
        case "recent", "search", "chat", "with": try messageOutputs(database, request)
        default: [.end(.failure("unsupported operation"))]
        }
    } catch let failure as BridgeFailure {
        return [.end(.failure(failure.publicMessage))]
    } catch {
        return [.end(.failure("unexpected bridge failure"))]
    }
}

let encodeOutput: (BridgeOutput) -> String? = { value in
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) }
}

#if !IMSG_HISTORY_TESTING
@main
enum MessageHistoryBridge {
    static func main() {
        let databasePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db").path
        let output = readLine()
            .flatMap { $0.utf8.count <= 16 * 1024 ? $0 : nil }
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(BridgeRequest.self, from: $0) }
            .map { execute($0, databasePath) }
            ?? [.end(.failure("request must be one JSON object"))]
        output.compactMap(encodeOutput).forEach { print($0) }
    }
}
#endif
