import AppKit

@MainActor
final class SearchModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            if query != oldValue { refilter(resetSelection: true) }
        }
    }
    @Published private(set) var results: [TabItem] = []
    @Published var selection: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errors: [String] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var hasRunningBrowser = true
    /// Number of tabs that are playing audio or capturing camera/mic/screen.
    @Published private(set) var activeMediaCount = 0
    /// Whether Taffy has the Accessibility permission needed for media indicators.
    @Published private(set) var mediaIndicatorsAvailable = MediaScanner.isTrusted
    /// Bumped every time the panel is shown so the view can refocus the field.
    @Published private(set) var focusToken = 0

    /// Called when the panel should be hidden. The argument tells whether the
    /// previously active app should get focus back (true for Esc).
    var onDismiss: ((_ restoreFocus: Bool) -> Void)?

    private let provider = TabProvider()
    private var tabsByBrowser: [String: [TabItem]] = [:]
    private var allTabs: [TabItem] = []
    private var generation = 0
    private var pending = 0
    private var iconCache: [String: NSImage] = [:]

    var selectedItem: TabItem? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    func prepareForShow() {
        query = ""
        selection = 0
        focusToken += 1
    }

    /// Re-reads tabs from every running browser. Results from each browser are
    /// shown as soon as they arrive; previously loaded tabs stay visible meanwhile.
    func reload() {
        generation += 1
        let gen = generation
        let browsers = provider.runningBrowsers()
        let running = Set(browsers.map(\.bundleID))
        tabsByBrowser = tabsByBrowser.filter { running.contains($0.key) }
        errors = []
        mediaIndicatorsAvailable = MediaScanner.isTrusted
        hasRunningBrowser = !browsers.isEmpty
        rebuild()

        pending = browsers.count
        isLoading = pending > 0
        let provider = self.provider
        for browser in browsers {
            Task {
                let result = await provider.fetch(browser)
                self.apply(result, generation: gen)
            }
        }
    }

    private func apply(_ result: TabFetchResult, generation gen: Int) {
        guard gen == generation else { return }
        pending -= 1
        if pending <= 0 { isLoading = false }
        if let error = result.error {
            errors.append(error)
            NSLog("Taffy: %@", error)
        }
        tabsByBrowser[result.browser.bundleID] = result.tabs
        rebuild()
    }

    private func rebuild() {
        allTabs = Browser.all.flatMap { tabsByBrowser[$0.bundleID] ?? [] }
        totalCount = allTabs.count
        activeMediaCount = allTabs.filter { !$0.media.intersection(.active).isEmpty }.count
        refilter(resetSelection: false)
    }

    private func refilter(resetSelection: Bool) {
        let previousID = selectedItem?.id
        var tokens = FuzzyMatcher.tokens(query)
        var mediaFilters: [MediaState] = []
        tokens.removeAll { token in
            guard let filter = MediaFilter.parse(token) else { return false }
            mediaFilters.append(filter)
            return true
        }
        let candidates = allTabs.enumerated().filter { _, item in
            mediaFilters.allSatisfy { !item.media.intersection($0).isEmpty }
        }
        if tokens.isEmpty {
            // Tabs using the camera/mic/screen or playing audio come first.
            results = candidates
                .sorted { a, b in
                    let pa = a.element.media.priority, pb = b.element.media.priority
                    return pa != pb ? pa < pb : a.offset < b.offset
                }
                .map { $0.element }
        } else {
            results = candidates
                .compactMap { offset, item -> (Int, TabItem, Int)? in
                    guard let score = FuzzyMatcher.score(item, tokens: tokens) else { return nil }
                    return (offset, item, score)
                }
                .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
                .map { $0.1 }
        }
        if resetSelection {
            selection = 0
        } else if let previousID, let index = results.firstIndex(where: { $0.id == previousID }) {
            selection = index
        } else {
            selection = min(selection, max(results.count - 1, 0))
        }
    }

    /// ⌘M: show only tabs with audio / camera / microphone / screen activity.
    func toggleMediaFilter() {
        query = query.hasPrefix(MediaFilter.mediaToken) ? "" : MediaFilter.mediaToken + " "
    }

    func enableMediaIndicators() {
        onDismiss?(false)
        if MediaScanner.isTrusted {
            MediaScanner.openAccessibilitySettings()
        } else {
            MediaScanner.requestAccess()
        }
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    func moveToEdge(top: Bool) {
        guard !results.isEmpty else { return }
        selection = top ? 0 : results.count - 1
    }

    func activateSelected() {
        guard let item = selectedItem else { return }
        onDismiss?(false)
        let provider = self.provider
        Task {
            do {
                try await provider.activate(item)
            } catch {
                NSLog("Taffy: failed to activate tab: %@", error.localizedDescription)
                // The tab list was probably stale; fall back to just bringing the browser forward.
                NSRunningApplication.runningApplications(withBundleIdentifier: item.browser.bundleID)
                    .first?.activate(options: [])
            }
        }
    }

    func closeSelected() {
        guard let item = selectedItem, !isLoading else { return }
        // Remove it right away so the list feels responsive, then re-read the
        // real state (tab indices of the remaining tabs shift).
        tabsByBrowser[item.browser.bundleID]?.removeAll { $0.id == item.id }
        rebuild()
        isLoading = true
        let provider = self.provider
        Task {
            do {
                try await provider.close(item)
            } catch {
                NSLog("Taffy: failed to close tab: %@", error.localizedDescription)
            }
            self.reload()
        }
    }

    func icon(for browser: Browser) -> NSImage {
        if let cached = iconCache[browser.bundleID] { return cached }
        let image: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        }
        iconCache[browser.bundleID] = image
        return image
    }
}

/// `@media`, `@camera`, `@mic`, `@screen`, `@audio`, `@muted` in the query.
/// A prefix works too (`@cam`), and `@m` matches every filter starting with m.
enum MediaFilter {
    static let mediaToken = "@media"

    private static let filters: [(name: String, state: MediaState)] = [
        ("media", .active),
        ("camera", .camera),
        ("video", .camera),
        ("mic", .microphone),
        ("microphone", .microphone),
        ("screen", .screen),
        ("audio", .audio),
        ("sound", .audio),
        ("muted", .muted),
    ]

    static func parse(_ token: String) -> MediaState? {
        guard token.hasPrefix("@") else { return nil }
        let name = token.dropFirst()
        let matches = filters.filter { $0.name.hasPrefix(name) }
        guard !matches.isEmpty else { return nil }
        return matches.reduce(into: MediaState()) { $0.formUnion($1.state) }
    }
}
