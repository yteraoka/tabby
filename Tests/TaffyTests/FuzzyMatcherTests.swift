import XCTest
@testable import Taffy

final class FuzzyMatcherTests: XCTestCase {
    private func tab(_ title: String, _ url: String = "https://example.com/") -> TabItem {
        TabItem(browser: Browser.all[0], windowID: "1", windowNumber: 1, tabIndex: 1,
                tabID: nil, title: title, url: url, isActive: false)
    }

    private func score(_ item: TabItem, _ query: String) -> Int? {
        FuzzyMatcher.score(item, tokens: FuzzyMatcher.tokens(query))
    }

    func testTokensAreNormalizedAndSplitOnWhitespace() {
        XCTAssertEqual(FuzzyMatcher.tokens("  GitHub   Pull "), ["github", "pull"])
        // Full-width letters fold to half-width.
        XCTAssertEqual(FuzzyMatcher.tokens("ＧｉｔＨｕｂ"), ["github"])
    }

    func testEveryTokenMustMatch() {
        let item = tab("Pull requests · yteraoka/taffy", "https://github.com/yteraoka/taffy/pulls")
        XCTAssertNotNil(score(item, "pull taffy"))
        XCTAssertNil(score(item, "pull gitlab"))
    }

    func testTitleMatchRanksAboveURLMatch() throws {
        let inTitle = tab("Swift documentation", "https://example.com/")
        let inURL = tab("Docs", "https://swift.org/documentation/")
        let titleScore = try XCTUnwrap(score(inTitle, "swift"))
        let urlScore = try XCTUnwrap(score(inURL, "swift"))
        XCTAssertGreaterThan(titleScore, urlScore)
    }

    func testPrefixMatchRanksAboveMiddleMatch() throws {
        let prefix = try XCTUnwrap(score(tab("Mail - Inbox"), "mail"))
        let middle = try XCTUnwrap(score(tab("Gmail - Inbox"), "mail"))
        XCTAssertGreaterThan(prefix, middle)
    }

    func testSubsequenceMatch() {
        XCTAssertNotNil(score(tab("GitHub"), "gthb"))
        XCTAssertNil(score(tab("GitHub"), "bhtg"))
    }

    func testBrowserNameMatches() {
        XCTAssertNotNil(score(tab("Anything"), "safari"))
    }

    func testJapaneseTitle() {
        XCTAssertNotNil(score(tab("天気予報 - 東京"), "東京"))
    }
}
