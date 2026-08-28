import Foundation

@main
enum ETaxWatchTests {
    static let loginFixture = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <XU00S010><XAB000><XAB010>SU00S010</XAB010><XAB020>handoff-login</XAB020></XAB000>
      <XAC000><XAC080><XAC090>https://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/loginKekka</XAC090></XAC080></XAC000>
    </XU00S010>
    """.utf8)

    static let noticeSwitchFixture = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <XU00SA10><ZTB000><ZTB020>handoff-notices</ZTB020></ZTB000><ZTC000><ZTC500>
      <ZTC520><ZTC530>別の通知</ZTC530><ZTC540>https://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/other</ZTC540></ZTC520>
      <ZTC520><ZTC530>適格請求書発行事業者通知書</ZTC530><ZTC540>https://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/invoiceNotice</ZTC540></ZTC520>
    </ZTC500></ZTC000></XU00SA10>
    """.utf8)

    static let invoiceFixture = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <XU00SB40><WDC000><WDC100><WDC190>
      <WDC260><WDC270>2026/08/27</WDC270><WDC280>2026/07/11</WDC280><WDC290>secret-a</WDC290><WDC300>2026/09/01</WDC300><WDC310>結果格納済み</WDC310><WDC330>0</WDC330></WDC260>
      <WDC260><WDC270>2026/08/20</WDC270><WDC280>2026/07/11</WDC280><WDC290>secret-b</WDC290><WDC300>2026/09/01</WDC300><WDC310>結果格納済み</WDC310><WDC330>1</WDC330></WDC260>
    </WDC190></WDC100></WDC000></XU00SB40>
    """.utf8)

    static let require: (Bool, String) -> Void = { condition, message in
        precondition(condition, message)
    }

    static let page: (Data) -> ReceptionPage = { data in
        try! ReceptionPage.parse(data, URL(string: "https://uketsuke.e-tax.nta.go.jp/")!).get()
    }

    static func main() {
        let credentials = Credentials(userNumber: "1234567890123456", passphrase: "example")
        require(validate(credentials) == nil, "valid credentials")
        require(validate(Credentials(userNumber: "123", passphrase: "example")) != nil, "invalid user number")

        let loginPage = page(loginFixture)
        require((try? loginPage.requiresScreen("XU00S010").get()) != nil, "login screen")
        let login = try! loginPage.form(actionPath: "/XU00S010/XAC000/XAC080/XAC090", handoffPath: "/XU00S010/XAB000/XAB020").get()
        require(login.action.absoluteString == "https://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/loginKekka", "login action")
        require(login.hiddenFields == [FormField(name: "oStHktgInf", value: "handoff-login")], "login handoff")

        let notices = page(noticeSwitchFixture)
        let switchForm = try! notices.invoiceRoute().get()
        require(switchForm.action.host == "uketsuke.e-tax.nta.go.jp", "invoice host")
        require(switchForm.hiddenFields == [FormField(name: "oStHktgInf", value: "handoff-notices")], "notice handoff")

        let summary = try! page(invoiceFixture).invoiceSummary().get()
        require(summary.noticeCount == 2, "notice count")
        require(summary.unreadCount == 1, "unread count")
        require(summary.latestIssueDate == "2026/08/27", "latest issue date")
        require(summary.latestRegistrationDate == "2026/09/01", "latest registration date")
        require(summary.fingerprint.count == 64, "fingerprint")
        require(!String(data: try! JSONEncoder().encode(summary), encoding: .utf8)!.contains("secret-a"), "receipt number is not projected")

        require(OfficialEndpoint.accepts(URL(string: "https://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/x")!), "official endpoint")
        require(!OfficialEndpoint.accepts(URL(string: "https://example.com/UF_APP/lnk/x")!), "foreign endpoint")
        require(!OfficialEndpoint.accepts(URL(string: "http://uketsuke.e-tax.nta.go.jp/UF_APP/lnk/x")!), "https only")
        require(formEscape("日 本") == "%E6%97%A5%20%E6%9C%AC", "form values use UTF-8 percent encoding")

        let rejected = verifyAndSave(
            credentials,
            { _ in .failure(BrokerFailure(code: "login_rejected", message: "rejected", status: "認証が必要")) },
            { _ in .success(true) }
        )
        require((try? rejected.get()) == nil, "rejected credentials are not enrolled")
        let accepted = verifyAndSave(
            credentials,
            { _ in .success(summary) },
            { _ in .success(true) }
        )
        require((try? accepted.get()) == true, "verified credentials are enrolled")

        print("etax-watch tests: 21 passed")
    }
}
