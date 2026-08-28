// etax-watchd.swift — e-Tax受付システムの読取専用資格情報・通信境界。
//
// 入力は固定commandだけ、出力は秘密値と受付番号を除いたJSONだけに限定する。
// Safari、Cookie、汎用HTTP proxy、任意URL、申告・送信・支払の経路は持たない。

import AppKit
import CryptoKit
import Foundation
import Security

struct BrokerFailure: Error, Codable, Equatable {
    let code: String
    let message: String
    let status: String
}

struct Credentials: Codable, Equatable {
    let userNumber: String
    let passphrase: String
}

struct FormField: Equatable {
    let name: String
    let value: String
}

struct FormSpec: Equatable {
    let action: URL
    let hiddenFields: [FormField]
}

struct InvoiceSummary: Codable, Equatable {
    let noticeCount: Int
    let unreadCount: Int
    let latestIssueDate: String?
    let latestRegistrationDate: String?
    let fingerprint: String
}

struct WatchResponse: Codable, Equatable {
    let ok: Bool
    let status: String
    let source: String
    let screen: String
    let checkedAt: String
    let summary: InvoiceSummary
}

struct StatusResponse: Codable, Equatable {
    let ok: Bool
    let status: String
    let enrolled: Bool
    let broker: String
}

struct ErrorResponse: Codable, Equatable {
    let ok: Bool
    let status: String
    let error: BrokerFailure
}

enum OfficialEndpoint {
    static let allowedHosts = Set([
        "login.e-tax.nta.go.jp",
        "uketsuke.e-tax.nta.go.jp",
    ])

    static let accepts: (URL) -> Bool = { url in
        url.scheme == "https" && url.host.map(allowedHosts.contains) == true
    }
}

let validate: (Credentials) -> BrokerFailure? = { credentials in
    credentials.userNumber.range(of: #"^[0-9]{16}$"#, options: .regularExpression) == nil
        ? BrokerFailure(code: "invalid_user_number", message: "利用者識別番号は16桁の数字で入力してください。", status: "入力を確認してください")
        : credentials.passphrase.isEmpty
            ? BrokerFailure(code: "empty_passphrase", message: "e-Taxのパスワードを入力してください。", status: "入力を確認してください")
            : nil
}

let normalizedText: (XMLNode) -> String = { node in
    (node.stringValue ?? "")
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

struct ReceptionPage {
    let document: XMLDocument
    let baseURL: URL

    static let parse: (Data, URL) -> Result<ReceptionPage, BrokerFailure> = { data, baseURL in
        Result {
            ReceptionPage(document: try XMLDocument(data: data), baseURL: baseURL)
        }.mapError { _ in
            BrokerFailure(code: "invalid_xml", message: "e-Taxの公式応答形式を確認できませんでした。", status: "一時的に取得できません")
        }
    }

    func text(_ xpath: String) -> String? {
        (try? document.nodes(forXPath: xpath).first).flatMap { $0 }.map(normalizedText).flatMap { $0.isEmpty ? nil : $0 }
    }

    func form(actionPath: String, handoffPath: String, additionalPaths: [(String, String)] = []) -> Result<FormSpec, BrokerFailure> {
        let action = text(actionPath)
            .flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
        let fields = [FormField(name: "oStHktgInf", value: text(handoffPath) ?? "")]
            + additionalPaths.compactMap { name, path in text(path).map { FormField(name: name, value: $0) } }
        return action.map { url in
            OfficialEndpoint.accepts(url)
                ? .success(FormSpec(action: url, hiddenFields: fields))
                : .failure(BrokerFailure(code: "foreign_form_action", message: "e-Tax以外への遷移を拒否しました。", status: "一時的に取得できません"))
        } ?? .failure(BrokerFailure(code: "missing_form_action", message: "e-Taxの遷移先を確認できませんでした。", status: "一時的に取得できません"))
    }

    func requiresScreen(_ screen: String) -> Result<ReceptionPage, BrokerFailure> {
        document.rootElement()?.name == screen
            ? .success(self)
            : .failure(BrokerFailure(
                code: screen == "XU00S020" ? "login_rejected" : "unexpected_screen",
                message: screen == "XU00S020" ? "e-Taxへログインできませんでした。保存内容を確認してください。" : "e-Taxの公式画面遷移を確認できませんでした。",
                status: screen == "XU00S020" ? "認証が必要" : "一時的に取得できません"
            ))
    }

    func invoiceRoute() -> Result<FormSpec, BrokerFailure> {
        requiresScreen("XU00SA10").flatMap { page in
            let nodes = (try? page.document.nodes(forXPath: "/XU00SA10/ZTC000/ZTC500/ZTC520")) ?? []
            let route = nodes.find { node in
                normalizedText((try? node.nodes(forXPath: "./ZTC530").first).flatMap { $0 } ?? node)
                    .contains("適格請求書発行事業者通知書")
            }
            let action = route
                .flatMap { (try? $0.nodes(forXPath: "./ZTC540").first).flatMap { $0 } }
                .map(normalizedText)
                .flatMap { URL(string: $0, relativeTo: page.baseURL)?.absoluteURL }
            let fields = [FormField(name: "oStHktgInf", value: page.text("/XU00SA10/ZTB000/ZTB020") ?? "")]
                + [("oStAgentRecptRtFlg", "/XU00SA10/ZTB000/ZTB030"), ("oStUserNoInin", "/XU00SA10/ZTB000/ZTB040")]
                    .compactMap { name, path in page.text(path).map { FormField(name: name, value: $0) } }
            return action.map { url in
                OfficialEndpoint.accepts(url)
                    ? .success(FormSpec(action: url, hiddenFields: fields))
                    : .failure(BrokerFailure(code: "foreign_option_url", message: "e-Tax以外への遷移を拒否しました。", status: "一時的に取得できません"))
            } ?? .failure(BrokerFailure(code: "missing_invoice_option", message: "適格請求書発行事業者通知書の一覧へ移動できませんでした。", status: "一時的に取得できません"))
        }
    }

    func invoiceSummary() -> Result<InvoiceSummary, BrokerFailure> {
        requiresScreen("XU00SB40").flatMap { page in
            Result { try page.document.nodes(forXPath: "/XU00SB40/WDC000/WDC100/WDC190/WDC260") }
                .mapError { _ in BrokerFailure(code: "invalid_invoice_rows", message: "通知書一覧を確認できませんでした。", status: "一時的に取得できません") }
                .flatMap { rows in
                    let parsed = rows.compactMap { row -> (String, String, String, String, String, Bool)? in
                        let value: (String) -> String? = { name in
                            (try? row.nodes(forXPath: "./\(name)").first).flatMap { $0 }.map(normalizedText)
                        }
                        return value("WDC270").flatMap { issue in
                            value("WDC280").flatMap { submitted in
                                value("WDC290").flatMap { receipt in
                                    value("WDC300").flatMap { registration in
                                        value("WDC310").map { result in
                                            (issue, submitted, receipt, registration, result, value("WDC330") == "0")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    let canonical = parsed.map { [$0.0, $0.1, $0.2, $0.3, $0.4, $0.5 ? "0" : "1"].joined(separator: "\u{1f}") }
                        .joined(separator: "\u{1e}")
                    let digest = SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
                    let summary = InvoiceSummary(
                        noticeCount: parsed.count,
                        unreadCount: parsed.filter(\.5).count,
                        latestIssueDate: parsed.map(\.0).filter { !$0.isEmpty }.max(),
                        latestRegistrationDate: parsed.map(\.3).filter { !$0.isEmpty }.max(),
                        fingerprint: digest
                    )
                    return parsed.count == rows.count
                        ? .success(summary)
                        : .failure(BrokerFailure(code: "incomplete_invoice_rows", message: "通知書一覧の一部を安全に解釈できませんでした。", status: "一時的に取得できません"))
                }
        }
    }
}

extension Array {
    func find(_ predicate: (Element) -> Bool) -> Element? { first(where: predicate) }
}

struct HTTPResponse {
    let data: Data
    let url: URL
}

final class ResultSlot<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value?

    func put(_ value: Value) {
        lock.lock()
        stored = value
        lock.unlock()
    }

    func get() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

final class OfficialRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(request.url.map(OfficialEndpoint.accepts) == true ? request : nil)
    }
}

struct HTTPClient {
    let session: URLSession

    static let live: HTTPClient = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return HTTPClient(session: URLSession(configuration: configuration, delegate: OfficialRedirectDelegate(), delegateQueue: nil))
    }()

    func send(_ request: URLRequest) -> Result<HTTPResponse, BrokerFailure> {
        let slot = ResultSlot<Result<HTTPResponse, BrokerFailure>>()
        let semaphore = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { data, response, error in
            let result: Result<HTTPResponse, BrokerFailure> = error.map { _ in
                .failure(BrokerFailure(code: "network_failure", message: "e-Taxへ接続できませんでした。", status: "一時的に取得できません"))
            } ?? (response as? HTTPURLResponse).map { http in
                let body = data ?? Data()
                return (200 ..< 300).contains(http.statusCode) && body.count <= 2_000_000 && http.url.map(OfficialEndpoint.accepts) == true
                    ? .success(HTTPResponse(data: body, url: http.url!))
                    : .failure(BrokerFailure(code: "invalid_http_response", message: "e-Taxの応答を安全に処理できませんでした。", status: "一時的に取得できません"))
            } ?? .failure(BrokerFailure(code: "missing_http_response", message: "e-Taxの応答を確認できませんでした。", status: "一時的に取得できません"))
            slot.put(result)
            semaphore.signal()
        }.resume()
        return semaphore.wait(timeout: .now() + 35) == .success
            ? slot.get() ?? .failure(BrokerFailure(code: "missing_network_result", message: "e-Taxの取得結果を確認できませんでした。", status: "一時的に取得できません"))
            : .failure(BrokerFailure(code: "network_timeout", message: "e-Taxへの接続が時間内に完了しませんでした。", status: "一時的に取得できません"))
    }

    func get(_ url: URL) -> Result<HTTPResponse, BrokerFailure> {
        OfficialEndpoint.accepts(url)
            ? send({
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("etax-watch/1.0", forHTTPHeaderField: "User-Agent")
                return request
            }())
            : .failure(BrokerFailure(code: "foreign_get_url", message: "e-Tax以外への接続を拒否しました。", status: "一時的に取得できません"))
    }

    func post(_ url: URL, fields: [FormField]) -> Result<HTTPResponse, BrokerFailure> {
        OfficialEndpoint.accepts(url)
            ? send({
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = Data(formEncoded(fields).utf8)
                request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                request.setValue("etax-watch/1.0", forHTTPHeaderField: "User-Agent")
                return request
            }())
            : .failure(BrokerFailure(code: "foreign_post_url", message: "e-Tax以外への接続を拒否しました。", status: "一時的に取得できません"))
    }
}

let formAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
let formEscape: (String) -> String = { value in
    value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? ""
}
let formEncoded: ([FormField]) -> String = { fields in
    fields.map { "\(formEscape($0.name))=\(formEscape($0.value))" }.joined(separator: "&")
}

struct ETaxService {
    let client: HTTPClient
    let loginURL = URL(string: "https://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/loginCtl")!

    func page(_ response: HTTPResponse) -> Result<ReceptionPage, BrokerFailure> {
        ReceptionPage.parse(response.data, response.url)
    }

    func submit(_ form: FormSpec, additional: [FormField] = []) -> Result<ReceptionPage, BrokerFailure> {
        client.post(form.action, fields: form.hiddenFields + additional).flatMap(page)
    }

    func watch(credentials: Credentials) -> Result<InvoiceSummary, BrokerFailure> {
        validate(credentials).map(Result.failure) ??
            client.get(loginURL)
                .flatMap(page)
                .flatMap { page in
                    page.requiresScreen("XU00S010").flatMap {
                        $0.form(actionPath: "/XU00S010/XAC000/XAC080/XAC090", handoffPath: "/XU00S010/XAB000/XAB020")
                    }
                }
                .flatMap {
                    submit($0, additional: [
                        FormField(name: "oStInputUserId", value: credentials.userNumber),
                        FormField(name: "oStInputPwd", value: credentials.passphrase),
                    ])
                }
                .flatMap { $0.requiresScreen("XU00S020") }
                .flatMap {
                    $0.form(actionPath: "/XU00S020/XBC000/XBC030[18]/XBC050", handoffPath: "/XU00S020/XBB000/XBB020")
                }
                .flatMap { submit($0) }
                .flatMap { $0.invoiceRoute() }
                .flatMap { submit($0) }
                .flatMap { $0.invoiceSummary() }
    }
}

let verifyAndSave: (
    Credentials,
    (Credentials) -> Result<InvoiceSummary, BrokerFailure>,
    (Credentials) -> Result<Bool, BrokerFailure>
) -> Result<Bool, BrokerFailure> = { credentials, verify, save in
    validate(credentials).map(Result.failure)
        ?? verify(credentials).flatMap { _ in save(credentials) }
}

enum KeychainStore {
    static let service = "com.tkgshn.etax-watch.credentials"
    static let account = "corporate"

    static let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
    ]

    static let exists: () -> Bool = {
        let request = query.merging([kSecReturnAttributes: true, kSecMatchLimit: kSecMatchLimitOne]) { _, new in new }
        return SecItemCopyMatching(request as CFDictionary, nil) == errSecSuccess
    }

    static let load: () -> Result<Credentials, BrokerFailure> = {
        let request = query.merging([kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        return status == errSecSuccess
            ? (item as? Data).map { data in
                Result { try JSONDecoder().decode(Credentials.self, from: data) }
                    .mapError { _ in BrokerFailure(code: "invalid_keychain_item", message: "保存済みのe-Tax接続情報を読み取れませんでした。", status: "認証が必要") }
            } ?? .failure(BrokerFailure(code: "missing_keychain_data", message: "保存済みのe-Tax接続情報を読み取れませんでした。", status: "認証が必要"))
            : .failure(BrokerFailure(code: "not_enrolled", message: "e-Tax接続情報の一度だけの登録が必要です。", status: "認証が必要"))
    }

    static let save: (Credentials) -> Result<Bool, BrokerFailure> = { credentials in
        validate(credentials).map(Result.failure) ?? Result { try JSONEncoder().encode(credentials) }
            .mapError { _ in BrokerFailure(code: "credential_encoding_failed", message: "e-Tax接続情報を保存できませんでした。", status: "一時的に取得できません") }
            .flatMap { data in
                let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
                let add = query.merging([
                    kSecValueData: data,
                    kSecAttrLabel: "e-Tax Read-Only Monitor",
                    kSecAttrDescription: "e-Tax受付システム通知の読取専用broker",
                    kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ]) { _, new in new }
                let finalStatus = updateStatus == errSecItemNotFound
                    ? SecItemAdd(add as CFDictionary, nil)
                    : updateStatus
                return finalStatus == errSecSuccess
                    ? .success(true)
                    : .failure(BrokerFailure(code: "keychain_write_failed", message: "Keychainへ保存できませんでした。", status: "一時的に取得できません"))
            }
    }
}

enum EnrollmentUI {
    static let run: () -> Result<Bool, BrokerFailure> = {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        app.activate(ignoringOtherApps: true)

        let userNumber = NSTextField(string: "")
        userNumber.placeholderString = "16桁の利用者識別番号"
        userNumber.maximumNumberOfLines = 1

        let passphrase = NSSecureTextField(string: "")
        passphrase.placeholderString = "e-Taxのパスワード"
        passphrase.maximumNumberOfLines = 1

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "利用者識別番号"), userNumber],
            [NSTextField(labelWithString: "パスワード"), passphrase],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 280
        grid.rowSpacing = 10
        grid.frame = NSRect(x: 0, y: 0, width: 410, height: 70)

        let alert = NSAlert()
        alert.messageText = "e-Tax無人監視を一度だけ設定"
        alert.informativeText = "e-Taxへ実際に接続できることを確認した後だけ、読取専用brokerのKeychain項目へ保存します。Codex・shell・ログには出ません。"
        alert.accessoryView = grid
        alert.addButton(withTitle: "接続を確認して保存")
        alert.addButton(withTitle: "キャンセル")
        alert.window.initialFirstResponder = userNumber

        let result = alert.runModal() == .alertFirstButtonReturn
            ? verifyAndSave(
                Credentials(userNumber: userNumber.stringValue, passphrase: passphrase.stringValue),
                { ETaxService(client: .live).watch(credentials: $0) },
                KeychainStore.save
            )
            : .failure(BrokerFailure(code: "enrollment_cancelled", message: "登録を中止しました。", status: "中止しました"))
        return result.mapError { failure in
            let errorAlert = NSAlert()
            errorAlert.alertStyle = .warning
            errorAlert.messageText = "e-Taxの接続確認が必要です"
            errorAlert.informativeText = failure.message
            errorAlert.addButton(withTitle: "閉じる")
            errorAlert.runModal()
            return failure
        }
    }
}

let isoTimestamp: () -> String = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: Date())
}

enum JSONOutput {
    static func encode<Value: Encodable>(_ value: Value) -> Result<Data, BrokerFailure> {
        Result {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(value)
        }.mapError { _ in BrokerFailure(code: "output_encoding_failed", message: "取得結果を出力できませんでした。", status: "一時的に取得できません") }
    }

    static func emit<Value: Encodable>(_ value: Value) -> Int32 {
        encode(value).map { data in
            FileHandle.standardOutput.write(data + Data([0x0a]))
            return Int32(0)
        }.getOrElse { _ in Int32(70) }
    }
}

extension Result {
    func getOrElse(_ fallback: (Failure) -> Success) -> Success {
        switch self {
        case .success(let value): value
        case .failure(let error): fallback(error)
        }
    }
}

#if !TESTING
@main
enum ETaxWatchBroker {
    static func main() {
        let command = CommandLine.arguments.dropFirst().first ?? "watch"
        let exitCode: Int32 = command == "status"
            ? JSONOutput.emit(StatusResponse(ok: true, status: KeychainStore.exists() ? "登録済み" : "認証が必要", enrolled: KeychainStore.exists(), broker: "com.tkgshn.etaxwatch"))
            : command == "enroll"
                ? EnrollmentUI.run().map { _ in JSONOutput.emit(StatusResponse(ok: true, status: "登録済み", enrolled: true, broker: "com.tkgshn.etaxwatch")) }
                    .getOrElse { JSONOutput.emit(ErrorResponse(ok: false, status: $0.status, error: $0)) == 0 ? 2 : 70 }
                : command == "watch"
                    ? KeychainStore.load()
                        .flatMap { ETaxService(client: .live).watch(credentials: $0) }
                        .map { summary in
                            JSONOutput.emit(WatchResponse(ok: true, status: "取得済み", source: "e-Tax受付システム", screen: "XU00SB40", checkedAt: isoTimestamp(), summary: summary))
                        }
                        .getOrElse { JSONOutput.emit(ErrorResponse(ok: false, status: $0.status, error: $0)) == 0 ? 1 : 70 }
                    : JSONOutput.emit(ErrorResponse(ok: false, status: "入力を確認してください", error: BrokerFailure(code: "unknown_command", message: "usage: etax-watch [status|enroll|watch]", status: "入力を確認してください"))) == 0 ? 64 : 70
        Foundation.exit(exitCode)
    }
}
#endif
