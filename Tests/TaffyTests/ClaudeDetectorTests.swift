import XCTest
@testable import Taffy

final class ClaudeDetectorTests: XCTestCase {
    func testClaudeCommands() {
        XCTAssertTrue(ClaudeDetector.isClaudeCommand("claude"))
        XCTAssertTrue(ClaudeDetector.isClaudeCommand("claude --resume"))
        XCTAssertTrue(ClaudeDetector.isClaudeCommand("/Users/me/.local/bin/claude"))
        XCTAssertTrue(ClaudeDetector.isClaudeCommand("/Users/me/.local/share/claude/versions/2.1.0 --continue"))
        XCTAssertTrue(ClaudeDetector.isClaudeCommand("node /opt/homebrew/bin/claude"))
        XCTAssertTrue(ClaudeDetector.isClaudeCommand(
            "node --no-warnings /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"))
    }

    func testOtherCommands() {
        XCTAssertFalse(ClaudeDetector.isClaudeCommand(""))
        XCTAssertFalse(ClaudeDetector.isClaudeCommand("-zsh"))
        XCTAssertFalse(ClaudeDetector.isClaudeCommand("vim claude.md"))
        XCTAssertFalse(ClaudeDetector.isClaudeCommand("node server.js"))
        XCTAssertFalse(ClaudeDetector.isClaudeCommand("/Applications/Claude.app/Contents/MacOS/Claude"))
    }

    func testParsePS() {
        let output = """
          101 ttys001  -zsh
          202 ttys002  claude --resume
          303 ??       /Users/me/.local/bin/claude mcp serve
          404 s004     node /opt/homebrew/bin/claude
        """
        XCTAssertEqual(ClaudeDetector.parsePS(output), [
            .init(pid: 202, tty: "ttys002"),
            .init(pid: 404, tty: "ttys004"),
        ])
    }

    func testParseLsof() {
        let output = "p202\nfcwd\nn/Users/me/src/taffy\np404\nfcwd\nn/tmp\n"
        XCTAssertEqual(ClaudeDetector.parseLsof(output), [202: "/Users/me/src/taffy", 404: "/tmp"])
    }

    func testShortTTY() {
        XCTAssertEqual(ClaudeDetector.shortTTY("/dev/ttys003"), "ttys003")
        XCTAssertEqual(ClaudeDetector.shortTTY("ttys003"), "ttys003")
    }

    func testTitles() {
        XCTAssertTrue(ClaudeDetector.titleLooksLikeClaude("✳ Fix the login bug"))
        XCTAssertTrue(ClaudeDetector.titleLooksLikeClaude("⠐ Fix the login bug"))
        XCTAssertTrue(ClaudeDetector.titleLooksLikeClaude("Claude Code"))
        XCTAssertFalse(ClaudeDetector.titleLooksLikeClaude("~/src/taffy"))
        XCTAssertFalse(ClaudeDetector.titleLooksLikeClaude(""))
    }

    func testClaudeFilter() {
        XCTAssertTrue(ClaudeFilter.matches("@claude"))
        XCTAssertTrue(ClaudeFilter.matches("@cl"))
        XCTAssertTrue(ClaudeFilter.matches("@cc"))
        XCTAssertFalse(ClaudeFilter.matches("@c"), "@c stays a prefix of @camera")
        XCTAssertFalse(ClaudeFilter.matches("@camera"))
        XCTAssertFalse(ClaudeFilter.matches("claude"))
    }

    func testClaudeTabsSortFirst() {
        let terminal = Browser.all.first { $0.kind == .ghostty }!
        var tab = TabItem(browser: terminal, windowID: "w", windowNumber: 1, tabIndex: 1,
                          tabID: nil, title: "zsh", url: "~", isActive: false)
        let plain = tab.priority
        tab.claudeCode = true
        XCTAssertLessThan(tab.priority, plain)
        XCTAssertTrue(tab.withURL("~/src").claudeCode, "withURL keeps the flags")
    }

    func testCategories() {
        XCTAssertEqual(BrowserKind.ghostty.category, .terminal)
        XCTAssertEqual(BrowserKind.appleTerminal.category, .terminal)
        XCTAssertEqual(BrowserKind.chromium.category, .browser)
        XCTAssertEqual(AppCategory.browser.other, .terminal)
    }
}
