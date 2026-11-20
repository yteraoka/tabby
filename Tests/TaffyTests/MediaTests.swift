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

final class CaptureInferenceTests: XCTestCase {
    private let brave = Browser.all.first { $0.bundleID == "com.brave.Browser" }!
    private let meet = "https://meet.google.com/abc-defg-hij"

    private func tab(_ url: String, _ media: MediaState = [], index: Int = 1) -> TabItem {
        var tab = TabItem(browser: brave, windowID: "1", windowNumber: 1, tabIndex: index,
                          tabID: nil, title: "t", url: url, isActive: false)
        tab.media = media
        return tab
    }

    func testMeetingSites() {
        XCTAssertTrue(CaptureInference.isMeetingSite(meet))
        XCTAssertTrue(CaptureInference.isMeetingSite("https://us02web.zoom.us/wc/123/join"))
        XCTAssertTrue(CaptureInference.isMeetingSite("https://teams.microsoft.com/v2/"))
        XCTAssertFalse(CaptureInference.isMeetingSite("https://www.youtube.com/watch?v=1"))
        XCTAssertFalse(CaptureInference.isMeetingSite("https://notzoom.us/"))
        XCTAssertFalse(CaptureInference.isMeetingSite("not a url"))
    }

    func testMeetingRooms() {
        XCTAssertTrue(CaptureInference.isMeetingRoom(meet))
        XCTAssertTrue(CaptureInference.isMeetingRoom(meet + "?authuser=0"))
        XCTAssertFalse(CaptureInference.isMeetingRoom("https://meet.google.com/"))
        XCTAssertFalse(CaptureInference.isMeetingRoom("https://meet.google.com/landing"))
        XCTAssertTrue(CaptureInference.isMeetingRoom("https://us02web.zoom.us/wc/123/join"))
        XCTAssertFalse(CaptureInference.isMeetingRoom("https://zoom.us/profile"))
        XCTAssertTrue(CaptureInference.isMeetingRoom("https://meet.jit.si/MyRoom"))
        XCTAssertFalse(CaptureInference.isMeetingRoom("https://meet.jit.si/"))
        XCTAssertFalse(CaptureInference.isMeetingRoom("https://teams.microsoft.com/v2/"))
    }

    // Tabs read from the tab strip (horizontal tabs).

    func testReadMeetingTabPlayingAudioGetsDevicesInUse() {
        let tabs = [tab(meet, .audio), tab("https://www.youtube.com/watch?v=1", .audio, index: 2)]
        let result = CaptureInference.apply([.camera, .microphone], to: tabs, read: [0, 1])
        XCTAssertEqual(result[0].media, [.audio, .camera, .microphone])
        XCTAssertEqual(result[1].media, .audio)
    }

    func testReadMutedMeetingTab() {
        let result = CaptureInference.apply(.microphone, to: [tab(meet, .muted)], read: [0])
        XCTAssertEqual(result[0].media, [.muted, .microphone])
    }

    func testReadSilentMeetingTabIsLeftAlone() {
        let result = CaptureInference.apply(.camera, to: [tab(meet)], read: [0])
        XCTAssertEqual(result[0].media, [])
    }

    func testReadTeamsTabPlayingAudio() {
        let result = CaptureInference.apply(.camera, to: [tab("https://teams.microsoft.com/v2/", .audio)], read: [0])
        XCTAssertEqual(result[0].media, [.audio, .camera])
    }

    func testStateAlreadyReportedByTabStrip() {
        let tabs = [tab(meet, .audio), tab("https://example.com/", .camera, index: 2)]
        let result = CaptureInference.apply([.camera, .microphone], to: tabs, read: [0, 1])
        XCTAssertEqual(result[0].media, [.audio, .microphone])
    }

    // Tabs the tab strip couldn't be read for (vertical tabs, Arc, no permission).

    func testUnreadMeetingRoomGetsDevicesInUse() {
        let tabs = [tab(meet), tab("https://meet.google.com/", index: 2),
                    tab("https://teams.microsoft.com/v2/", index: 3)]
        let result = CaptureInference.apply([.camera, .microphone], to: tabs, read: [])
        XCTAssertEqual(result[0].media, [.camera, .microphone])
        XCTAssertEqual(result[1].media, [])
        XCTAssertEqual(result[2].media, [])
    }

    func testNothingInUse() {
        let result = CaptureInference.apply([], to: [tab(meet, .audio), tab(meet, index: 2)], read: [0])
        XCTAssertEqual(result[0].media, .audio)
        XCTAssertEqual(result[1].media, [])
    }
}
