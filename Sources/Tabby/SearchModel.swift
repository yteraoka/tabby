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
            NSLog("Tabby: %@", error)
        }
        tabsByBrowser[result.browser.bundleID] = result.tabs
        rebuild()
    }

    private func rebuild() {
        allTabs = Browser.all.flatMap { tabsByBrowser[$0.bundleID] ?? [] }
        totalCount = allTabs.count
        refilter(resetSelection: false)
    }

    private func refilter(resetSelection: Bool) {
        let previousID = selectedItem?.id
        let tokens = FuzzyMatcher.tokens(query)
        if tokens.isEmpty {
            results = allTabs
        } else {
            results = allTabs.enumerated()
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
                NSLog("Tabby: failed to activate tab: %@", error.localizedDescription)
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
                NSLog("Tabby: failed to close tab: %@", error.localizedDescription)
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
