import Foundation
import CSQLite

private let testTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

let sql: (OpaquePointer, String) -> Void = { database, statement in
    precondition(sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK, statement)
}

let hexadecimal: (Data) -> String = {
    $0.map { String(format: "%02x", $0) }.joined()
}

let typedstreamFixture: (String) -> Data = { text in
    Data([0x04, 0x0B] + [UInt8]("NSString".utf8) + [0x01, 0x2B, UInt8(text.utf8.count)] + text.utf8)
}

let makeFixture: (String) -> Void = { path in
    var opened: OpaquePointer?
    precondition(sqlite3_open(path, &opened) == SQLITE_OK)
    let database = opened!
    defer { sqlite3_close(database) }
    [
        "CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT)",
        "CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT)",
        "CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER)",
        "CREATE TABLE message (ROWID INTEGER PRIMARY KEY, guid TEXT, date INTEGER, is_from_me INTEGER, handle_id INTEGER, text TEXT, attributedBody BLOB, service TEXT)",
        "CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER)",
        "CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER)",
        "INSERT INTO handle VALUES (1, '+819000000001'), (2, 'bob@example.com')",
        "INSERT INTO chat VALUES (1, 'iMessage;+;+819000000001', NULL), (2, 'chat-group', 'Project')",
        "INSERT INTO chat_handle_join VALUES (1, 1), (2, 1), (2, 2)",
        "INSERT INTO message VALUES (1, 'm1', 1000000000000000000, 0, 1, 'hello', NULL, 'iMessage')",
        "INSERT INTO message VALUES (2, 'm2', 1000000001000000000, 1, NULL, NULL, X'\(hexadecimal(typedstreamFixture("group hello")))', 'iMessage')",
        "INSERT INTO message VALUES (3, 'm3', 1000000002000000000, 0, 2, NULL, X'00', 'iMessage')",
        "INSERT INTO message VALUES (4, 'orphan', 1000000003000000000, 0, 2, 'deleted remnant', NULL, 'iMessage')",
        "INSERT INTO chat_message_join VALUES (1, 1), (1, 2), (2, 2), (2, 3)",
        "INSERT INTO message_attachment_join VALUES (3, 1)",
    ].forEach { sql(database, $0) }
}

let messages: ([BridgeOutput]) -> [MessageRecord] = {
    $0.compactMap {
        switch $0 {
        case let .message(envelope): envelope.message
        case .chat, .end: nil
        }
    }
}

let chats: ([BridgeOutput]) -> [ChatRecord] = {
    $0.compactMap {
        switch $0 {
        case let .chat(envelope): envelope.chat
        case .message, .end: nil
        }
    }
}

let terminal: ([BridgeOutput]) -> EndRecord? = {
    $0.compactMap {
        switch $0 {
        case let .end(record): record
        case .message, .chat: nil
        }
    }.last
}

@main
enum MessageHistoryBridgeTests {
    static func main() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("imsgd-test-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        makeFixture(path)

        let recent = messages(execute(
            BridgeRequest(op: "recent", spec: QuerySpec(
                limit: 10, query: nil, handle: nil, chatGUID: nil, before: nil)),
            path))
        let search = messages(execute(
            BridgeRequest(op: "search", spec: QuerySpec(
                limit: 10, query: "group", handle: nil, chatGUID: nil, before: nil)),
            path))
        let withAlice = messages(execute(
            BridgeRequest(op: "with", spec: QuerySpec(
                limit: 10, query: nil, handle: "+819000000001", chatGUID: nil, before: nil)),
            path))
        let knownChats = chats(execute(
            BridgeRequest(op: "chats", spec: QuerySpec(
                limit: 10, query: nil, handle: nil, chatGUID: nil, before: nil)),
            path))
        let latestPageOutput = execute(
            BridgeRequest(op: "recent", spec: QuerySpec(
                limit: 2, query: nil, handle: nil, chatGUID: nil, before: nil)),
            path)
        let olderPage = terminal(latestPageOutput)?.nextCursor.map { cursor in
            messages(execute(
                BridgeRequest(op: "recent", spec: QuerySpec(
                    limit: 2, query: nil, handle: nil, chatGUID: nil, before: cursor)),
                path))
        }

        assert(recent.count == 4)
        assert(recent.map(\.guid) == ["m1", "m2", "m2", "m3"])
        assert(recent[1].text == "group hello")
        assert(recent[1].decodeStatus == .typedstreamHeuristic)
        assert(recent[3].decodeStatus == .attachmentOnly)
        assert(recent.filter { $0.guid == "m2" }.map(\.chatGUID) == [
            "iMessage;+;+819000000001", "chat-group",
        ])
        assert(search.map(\.guid) == ["m2", "m2"])
        // Chat 2 is a group alice is in, so neither its copy of m2 nor bob's m3
        // belongs to the direct thread. Membership alone would return both.
        assert(withAlice.map(\.guid) == ["m1", "m2"])
        assert(withAlice.allSatisfy { $0.chatGUID == "iMessage;+;+819000000001" })
        assert(knownChats.count == 2)
        assert(knownChats.first { $0.guid == "chat-group" }?.participants == ["+819000000001", "bob@example.com"])
        assert(terminal(latestPageOutput)?.nextCursor == MessageCursor(
            dateRaw: 1000000001000000000, rowID: 2, chatRowID: 2))
        assert(olderPage?.map(\.guid) == ["m1", "m2"])
        assert(olderPage?.last?.chatRowID == 1)
        assert(decodeTypedstream(Data([0x00])) == nil)
        assert(execute(BridgeRequest(op: "recent", spec: QuerySpec(
            limit: 0, query: nil, handle: nil, chatGUID: nil, before: nil)), path)
            == [.end(.failure("limit must be between 1 and 1000"))])

        print("message-historyd tests: passed")
    }
}
