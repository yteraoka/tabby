import CoreAudio
import CoreMediaIO
import Foundation

/// Guesses which tab is using the camera / microphone when the tab strip
/// doesn't say.
///
/// Chromium shows only one alert per tab, and a video call is always playing
/// audio, so Brave (and recent Chrome) label a Google Meet tab "Audio playing"
/// rather than "Camera recording". macOS does tell whether *some* app is using
/// a camera or microphone, so a meeting site tab that plays audio while one is
/// in use is assumed to be the one using it. This is a guess: another app
/// using the camera at the same time also lights the tab up.
enum CaptureInference {
    /// Hosts (and their subdomains) of web meeting services.
    static let meetingHosts = [
        "meet.google.com",
        "zoom.us",
        "zoom.com",
        "teams.microsoft.com",
        "teams.live.com",
        "teams.cloud.microsoft",
        "webex.com",
        "whereby.com",
        "meet.jit.si",
        "app.chime.aws",
    ]

    static func isMeetingSite(_ url: String) -> Bool {
        guard let host = URLComponents(string: url)?.host?.lowercased() else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Adds the capture states in `inUse` (camera / microphone being used
    /// somewhere on the Mac) to meeting site tabs that are playing (or muted)
    /// audio. A state is only added when no tab of the browser already reports
    /// it on its own.
    static func apply(_ inUse: MediaState, to tabs: [TabItem]) -> [TabItem] {
        let reported = tabs.reduce(into: MediaState()) { $0.formUnion($1.media) }
        let missing = inUse.intersection([.camera, .microphone]).subtracting(reported)
        guard !missing.isEmpty else { return tabs }
        return tabs.map { tab in
            var tab = tab
            if !tab.media.intersection([.audio, .muted]).isEmpty, isMeetingSite(tab.url) {
                tab.media.formUnion(missing)
            }
            return tab
        }
    }
}

/// Whether any camera or microphone on the Mac is in use by some process.
/// Reading this needs no permission and doesn't open the devices.
enum CaptureDevices {
    static func inUse() -> MediaState {
        var state: MediaState = []
        if isAnyCameraRunning() { state.insert(.camera) }
        if isAnyMicrophoneRunning() { state.insert(.microphone) }
        return state
    }

    // MARK: Camera (CoreMediaIO)

    private static func isAnyCameraRunning() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else {
            return false
        }

        address.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        return devices.contains { device in
            var running: UInt32 = 0
            var dataUsed: UInt32 = 0
            let status = CMIOObjectGetPropertyData(device, &address, 0, nil,
                                                   UInt32(MemoryLayout<UInt32>.size), &dataUsed, &running)
            return status == noErr && running != 0
        }
    }

    // MARK: Microphone (CoreAudio)

    private static func isAnyMicrophoneRunning() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else {
            return false
        }
        return devices.contains { hasInput($0) && isRunningSomewhere($0) }
    }

    private static func hasInput(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeInput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isRunningSomewhere(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceIsRunningSomewhere),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr && running != 0
    }
}
