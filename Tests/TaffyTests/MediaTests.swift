import XCTest
@testable import Taffy

final class MediaScannerClassifyTests: XCTestCase {
    func testChromiumLabels() {
        XCTAssertEqual(MediaScanner.classify(" - audio playing"), .audio)
        XCTAssertEqual(MediaScanner.classify(" - audio muted"), .muted)
        XCTAssertEqual(MediaScanner.classify(" - camera recording"), .camera)
        XCTAssertEqual(MediaScanner.classify(" - microphone recording"), .microphone)
        XCTAssertEqual(MediaScanner.classify(" - camera or microphone recording"), [.camera, .microphone])
        XCTAssertEqual(MediaScanner.classify(" - sharing your screen"), .screen)
    }

    func testSafariMuteButton() {
        XCTAssertEqual(MediaScanner.classify(" | mute this tab"), .audio)
        XCTAssertEqual(MediaScanner.classify(" | unmute this tab"), .muted)
    }

    func testJapaneseLabels() {
        XCTAssertEqual(MediaScanner.classify(" - 音声を再生中"), .audio)
        XCTAssertEqual(MediaScanner.classify(" - カメラを使用中"), .camera)
        XCTAssertEqual(MediaScanner.classify(" - マイクを使用中"), .microphone)
        XCTAssertEqual(MediaScanner.classify(" - ミュート中"), .muted)
    }

    func testPlainTabHasNoState() {
        XCTAssertEqual(MediaScanner.classify(""), [])
        XCTAssertEqual(MediaScanner.classify(" | close tab"), [])
    }

    func testPriority() {
        XCTAssertLessThan(MediaState.camera.priority, MediaState.audio.priority)
        XCTAssertLessThan(MediaState.audio.priority, MediaState.muted.priority)
        XCTAssertLessThan(MediaState.muted.priority, MediaState().priority)
    }
}

final class MediaFilterTests: XCTestCase {
    func testExactNames() {
        XCTAssertEqual(MediaFilter.parse("@media"), .active)
        XCTAssertEqual(MediaFilter.parse("@camera"), .camera)
        XCTAssertEqual(MediaFilter.parse("@mic"), .microphone)
        XCTAssertEqual(MediaFilter.parse("@screen"), .screen)
        XCTAssertEqual(MediaFilter.parse("@audio"), .audio)
        XCTAssertEqual(MediaFilter.parse("@muted"), .muted)
    }

    func testPrefixes() {
        XCTAssertEqual(MediaFilter.parse("@cam"), .camera)
        // "@m" covers media, mic, microphone and muted.
        XCTAssertEqual(MediaFilter.parse("@m"), MediaState.active.union(.muted))
        XCTAssertEqual(MediaFilter.parse("@"), MediaState.active.union(.muted))
    }

    func testNonFilters() {
        XCTAssertNil(MediaFilter.parse("media"))
        XCTAssertNil(MediaFilter.parse("@xyz"))
    }
}
