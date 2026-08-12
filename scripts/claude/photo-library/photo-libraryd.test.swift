import Foundation

@main
enum PhotoLibraryBridgeTests {
    static func main() {
        let strong = evaluateCardCandidate(
            ["山田 太郎", "株式会社 Example", "代表取締役", "taro@example.com", "03-1234-5678"],
            true)
        let document = evaluateCardCandidate(
            ["会議資料", "議題", "次回日程", "検討事項"],
            false)
        let emailOnly = evaluateCardCandidate(["hello@example.com", "memo", "today"], false)
        let webScreenshot = evaluateCardCandidate(
            ["メニュー", "さば", "カートに追加", "www.example.jp"],
            true)
        let croppedCard = evaluateCardCandidate(
            ["株式会社 Example", "代表取締役", "taro@example.com", "03-1234-5678"],
            false)

        assert(strong.candidate)
        assert(strong.score >= 0.9)
        assert(!document.candidate)
        assert(!emailOnly.candidate)
        assert(!webScreenshot.candidate)
        assert(croppedCard.candidate)
        assert(validRunID("2026-08-03_abcd"))
        assert(!validRunID("../escape"))
        assert(!validRunID(""))
        switch exactlyOne(["hair"].filter { $0 == "hair" }) {
        case let .one(value): assert(value == "hair")
        case .none, .many: assertionFailure("one exact album must be selected")
        }
        switch exactlyOne(["hair", "hair"].filter { $0 == "hair" }) {
        case let .many(values): assert(values.count == 2)
        case .none, .one: assertionFailure("duplicate album names must remain ambiguous")
        }
        switch exactlyOne([String]()) {
        case .none: break
        case .one, .many: assertionFailure("missing album must remain missing")
        }
        assert(safeVideoExtension("tutorial.MOV") == "mov")
        assert(safeVideoExtension("tutorial.exe") == "mov")
        print("photo-libraryd tests: passed")
    }
}
