import Foundation

/// AppleScript / JXA sources used to talk to the browsers.
enum Scripts {
    /// JXA script that lists every tab of a browser as JSON.
    /// argv: [bundleID, kind]
    static let fetchTabs = """
    function run(argv) {
      var bundleID = argv[0];
      var kind = argv[1];
      var app = Application(bundleID);
      var toText = function (x) { return x === null || x === undefined ? '' : String(x); };
      var result = [];
      var wins = app.windows;
      var count = wins.length;
      for (var i = 0; i < count; i++) {
        var w = wins[i];
        try {
          var titles = kind === 'safari' ? w.tabs.name() : w.tabs.title();
          var urls = w.tabs.url();
          var ids = [];
          if (kind !== 'safari') {
            try { ids = w.tabs.id(); } catch (e) {}
          }
          var active = 0;
          try {
            if (kind === 'safari') {
              active = w.currentTab.index();
            } else if (kind === 'chromium') {
              active = w.activeTabIndex();
            } else {
              active = ids.map(toText).indexOf(toText(w.activeTab.id())) + 1;
            }
          } catch (e) {}
          result.push({
            id: toText(w.id()),
            active: active || 0,
            titles: titles.map(toText),
            urls: urls.map(toText),
            ids: ids.map(toText)
          });
        } catch (e) {}
      }
      return JSON.stringify(result);
    }
    """

    /// Common prologue: resolves `w` (window) and `tidx` (tab index) from argv.
    /// argv: [windowID, tabIndex, tabID or ""]
    private static func prologue(_ bundleID: String) -> String {
        """
        on run argv
        \tset widText to item 1 of argv
        \tset tidx to (item 2 of argv) as integer
        \tset tidText to item 3 of argv
        \ttell application id "\(bundleID)"
        \t\ttry
        \t\t\tset w to window id (widText as integer)
        \t\ton error
        \t\t\tset w to window id widText
        \t\tend try
        \t\tif tidText is not "" then
        \t\t\ttry
        \t\t\t\tset tabIDs to id of tabs of w
        \t\t\t\trepeat with i from 1 to count of tabIDs
        \t\t\t\t\tif ((item i of tabIDs) as text) is tidText then
        \t\t\t\t\t\tset tidx to i
        \t\t\t\t\t\texit repeat
        \t\t\t\t\tend if
        \t\t\t\tend repeat
        \t\t\tend try
        \t\tend if

        """
    }

    private static let epilogue = """
    \tend tell
    end run
    """

    /// AppleScript that focuses the tab and brings its window to the front.
    static func activate(_ browser: Browser) -> String {
        let body: String
        switch browser.kind {
        case .chromium:
            body = """
            \t\ttry
            \t\t\tif minimized of w then set minimized of w to false
            \t\tend try
            \t\tset active tab index of w to tidx
            \t\tset index of w to 1
            \t\tactivate

            """
        case .safari:
            body = """
            \t\ttry
            \t\t\tif miniaturized of w then set miniaturized of w to false
            \t\tend try
            \t\tset current tab of w to tab tidx of w
            \t\tset index of w to 1
            \t\tactivate

            """
        case .arc:
            body = """
            \t\ttell tab tidx of w to select
            \t\tactivate

            """
        }
        return prologue(browser.bundleID) + body + epilogue
    }

    /// AppleScript that closes the tab.
    static func close(_ browser: Browser) -> String {
        prologue(browser.bundleID) + "\t\tclose tab tidx of w\n" + epilogue
    }
}
