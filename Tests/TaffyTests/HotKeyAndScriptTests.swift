import AppKit
import Carbon
import XCTest
@testable import Taffy

final class HotKeySpecTests: XCTestCase {
    func testDefault() throws {
        let spec = try XCTUnwrap(HotKeySpec.parse(HotKeySpec.defaultString))
        XCTAssertEqual(spec.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(spec.modifiers, UInt32(cmdKey) | UInt32(shiftKey))
        XCTAssertEqual(spec.display, "⇧⌘Space")
    }

    func testAliasesAndOrder() throws {
        let spec = try XCTUnwrap(HotKeySpec.parse("Alt + Ctrl + T"))
        XCTAssertEqual(spec.modifiers, UInt32(optionKey) | UInt32(controlKey))
        XCTAssertEqual(spec.display, "⌃⌥T")
    }

    func testInvalid() {
        XCTAssertNil(HotKeySpec.parse("space"), "a modifier is required")
        XCTAssertNil(HotKeySpec.parse("cmd+nosuchkey"))
        XCTAssertNil(HotKeySpec.parse("cmd+a+b"), "only one key")
    }
}

final class ScriptsTests: XCTestCase {
    private func browser(_ kind: BrowserKind) -> Browser {
        Browser.all.first { $0.kind == kind }!
    }

    func testActivateScriptsTargetTheBrowser() {
        let chrome = Scripts.activate(browser(.chromium))
        XCTAssertTrue(chrome.contains("tell application id \"\(browser(.chromium).bundleID)\""))
        XCTAssertTrue(chrome.contains("set active tab index of w to tidx"))

        let safari = Scripts.activate(browser(.safari))
        XCTAssertTrue(safari.contains("set current tab of w to tab tidx of w"))

        let arc = Scripts.activate(browser(.arc))
        XCTAssertTrue(arc.contains("tell tab tidx of w to select"))
    }

    func testScriptsAreWellFormed() {
        for kind in [BrowserKind.chromium, .safari, .arc] {
            for script in [Scripts.activate(browser(kind)), Scripts.close(browser(kind))] {
                XCTAssertTrue(script.hasPrefix("on run argv"))
                XCTAssertTrue(script.hasSuffix("end run"))
                XCTAssertEqual(script.components(separatedBy: "tell application id").count, 2)
            }
        }
    }

    /// Compiles the AppleScripts with osacompile. Compiling resolves each
    /// browser's terminology, so this only runs for browsers that are installed.
    func testScriptsCompileForInstalledBrowsers() throws {
        var compiled = 0
        for browser in Browser.all
        where NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) != nil {
            for script in [Scripts.activate(browser), Scripts.close(browser)] {
                let out = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".scpt")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
                process.arguments = ["-o", out.path, "-e", script]
                try process.run()
                process.waitUntilExit()
                XCTAssertEqual(process.terminationStatus, 0, "\(browser.name) script failed to compile")
                try? FileManager.default.removeItem(at: out)
                compiled += 1
            }
        }
        if compiled == 0 { throw XCTSkip("no supported browser installed") }
    }
}
