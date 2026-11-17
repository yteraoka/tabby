import Foundation

/// How a browser exposes its tabs over AppleScript.
enum BrowserKind: String, Hashable, Sendable {
    /// Chrome-compatible scripting dictionary (Chrome, Brave, Edge, Vivaldi, ...).
    case chromium
    /// Safari's scripting dictionary.
    case safari
    /// Arc's scripting dictionary (tabs are selected with the `select` command).
    case arc
}

struct Browser: Hashable, Sendable {
    let name: String
    let bundleID: String
    let kind: BrowserKind

    /// Supported browsers, in the order their tabs are listed.
    static let all: [Browser] = [
        Browser(name: "Safari", bundleID: "com.apple.Safari", kind: .safari),
        Browser(name: "Safari Technology Preview", bundleID: "com.apple.SafariTechnologyPreview", kind: .safari),
        Browser(name: "Google Chrome", bundleID: "com.google.Chrome", kind: .chromium),
        Browser(name: "Google Chrome Beta", bundleID: "com.google.Chrome.beta", kind: .chromium),
        Browser(name: "Google Chrome Dev", bundleID: "com.google.Chrome.dev", kind: .chromium),
        Browser(name: "Google Chrome Canary", bundleID: "com.google.Chrome.canary", kind: .chromium),
        Browser(name: "Chromium", bundleID: "org.chromium.Chromium", kind: .chromium),
        Browser(name: "Brave", bundleID: "com.brave.Browser", kind: .chromium),
        Browser(name: "Brave Beta", bundleID: "com.brave.Browser.beta", kind: .chromium),
        Browser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", kind: .chromium),
        Browser(name: "Microsoft Edge Beta", bundleID: "com.microsoft.edgemac.Beta", kind: .chromium),
        Browser(name: "Microsoft Edge Dev", bundleID: "com.microsoft.edgemac.Dev", kind: .chromium),
        Browser(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", kind: .chromium),
        Browser(name: "Arc", bundleID: "company.thebrowser.Browser", kind: .arc),
    ]
}

struct TabItem: Identifiable, Hashable, Sendable {
    let browser: Browser
    /// The browser's own window id (number or string, kept as text).
    let windowID: String
    /// 1-based position of the window in the browser's window list (for display).
    let windowNumber: Int
    /// 1-based index of the tab within its window.
    let tabIndex: Int
    /// The browser's own tab id, when it has one (Chromium, Arc).
    let tabID: String?
    let title: String
    let url: String
    let isActive: Bool

    /// Normalized fields used for matching.
    let searchTitle: String
    let searchURL: String
    let searchBrowser: String

    var id: String { "\(browser.bundleID)|\(windowID)|\(tabIndex)" }

    var displayTitle: String { title.isEmpty ? url : title }

    init(browser: Browser, windowID: String, windowNumber: Int, tabIndex: Int,
         tabID: String?, title: String, url: String, isActive: Bool) {
        self.browser = browser
        self.windowID = windowID
        self.windowNumber = windowNumber
        self.tabIndex = tabIndex
        self.tabID = tabID
        self.title = title
        self.url = url
        self.isActive = isActive
        self.searchTitle = FuzzyMatcher.normalize(title)
        self.searchURL = FuzzyMatcher.normalize(url)
        self.searchBrowser = FuzzyMatcher.normalize(browser.name)
    }
}
