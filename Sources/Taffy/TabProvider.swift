import AppKit

struct TabFetchResult: Sendable {
    let browser: Browser
    let tabs: [TabItem]
    let error: String?
}

enum ScriptError: LocalizedError {
    case failed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            if message.contains("-1743") {
                return "not allowed to control this browser (System Settings > Privacy & Security > Automation)"
            }
            return message
        case .timedOut:
            return "timed out"
        }
    }
}

/// Reads and manipulates browser tabs through `osascript`.
///
/// `osascript` runs in a child process, so several browsers can be queried in
/// parallel without blocking the UI (NSAppleScript is not safe to use that way).
struct TabProvider: Sendable {
    func runningBrowsers() -> [Browser] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        return Browser.all.filter { running.contains($0.bundleID) }
    }

    func fetch(_ browser: Browser) async -> TabFetchResult {
        do {
            let output = try await OSAScript.run(
                source: Scripts.fetchTabs,
                javaScript: true,
                arguments: [browser.bundleID, browser.kind.rawValue],
                timeout: 30
            )
            let tabs = MediaScanner.annotate(try parse(output, browser: browser), browser: browser)
            return TabFetchResult(browser: browser, tabs: tabs, error: nil)
        } catch {
            return TabFetchResult(browser: browser, tabs: [],
                                  error: "\(browser.name): \(error.localizedDescription)")
        }
    }

    func activate(_ tab: TabItem) async throws {
        _ = try await OSAScript.run(source: Scripts.activate(tab.browser),
                                    arguments: arguments(for: tab))
    }

    func close(_ tab: TabItem) async throws {
        _ = try await OSAScript.run(source: Scripts.close(tab.browser),
                                    arguments: arguments(for: tab))
    }

    private func arguments(for tab: TabItem) -> [String] {
        [tab.windowID, String(tab.tabIndex), tab.tabID ?? ""]
    }

    private struct RawWindow: Decodable {
        let id: String
        let active: Int
        let titles: [String]
        let urls: [String]
        let ids: [String]
    }

    private func parse(_ output: String, browser: Browser) throws -> [TabItem] {
        guard !output.isEmpty else { return [] }
        let windows = try JSONDecoder().decode([RawWindow].self, from: Data(output.utf8))
        var tabs: [TabItem] = []
        for (windowOffset, window) in windows.enumerated() {
            for i in 0..<min(window.titles.count, window.urls.count) {
                tabs.append(TabItem(
                    browser: browser,
                    windowID: window.id,
                    windowNumber: windowOffset + 1,
                    tabIndex: i + 1,
                    tabID: i < window.ids.count && !window.ids[i].isEmpty ? window.ids[i] : nil,
                    title: window.titles[i],
                    url: window.urls[i],
                    isActive: window.active == i + 1
                ))
            }
        }
        return tabs
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

enum OSAScript {
    /// Runs a script with `/usr/bin/osascript` and returns its trimmed stdout.
    static func run(source: String, javaScript: Bool = false, arguments: [String] = [],
                    timeout: TimeInterval = 10) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                var args: [String] = []
                if javaScript { args += ["-l", "JavaScript"] }
                args += ["-e", source]
                args += arguments
                process.arguments = args

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let killer = DispatchWorkItem {
                    if process.isRunning { process.terminate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

                // Drain both pipes concurrently so a large output can't deadlock.
                let errBox = DataBox()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    errBox.data = stderr.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                group.wait()
                process.waitUntilExit()
                killer.cancel()

                if process.terminationReason == .uncaughtSignal {
                    continuation.resume(throwing: ScriptError.timedOut)
                } else if process.terminationStatus != 0 {
                    let message = String(decoding: errBox.data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: ScriptError.failed(message))
                } else {
                    let output = String(decoding: outData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: output)
                }
            }
        }
    }
}
