import Foundation

/// AppleScript / JXA sources used to talk to the browsers and terminals.
enum Scripts {
    /// The JXA script that lists the tabs of an app of this kind as JSON:
    /// `[{id, active, titles, urls, ids, ttys?}]`, one object per window.
    static func fetchTabs(for kind: BrowserKind) -> String {
        switch kind {
        case .chromium, .safari, .arc: return fetchBrowserTabs
        case .ghostty: return fetchGhosttyTabs
        case .appleTerminal: return fetchTerminalTabs
        }
    }

    /// JXA script that lists every tab of a browser as JSON.
    /// argv: [bundleID, kind]
    static let fetchBrowserTabs = """
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

    /// Ghostty (1.3+). A tab can hold several terminals (splits); the tab's
    /// "URL" is the working directory of its focused terminal, and the ttys of
    /// all its terminals are listed so Claude Code can be found in any split.
    /// `tty` is missing on some versions, so it is read separately.
    /// argv: [bundleID]
    static let fetchGhosttyTabs = """
    function run(argv) {
      var app = Application(argv[0]);
      var toText = function (x) { return x === null || x === undefined ? '' : String(x); };
      var result = [];
      var wins = app.windows;
      var count = wins.length;
      for (var i = 0; i < count; i++) {
        var w = wins[i];
        try {
          var tabs = w.tabs;
          var n = tabs.length;
          var titles = [], urls = [], ids = [], ttys = [];
          var active = 0;
          for (var j = 0; j < n; j++) {
            var t = tabs[j];
            var title = '', dir = '', id = '', tty = [];
            try { title = toText(t.name()); } catch (e) {}
            try { id = toText(t.id()); } catch (e) {}
            try { if (t.selected()) { active = j + 1; } } catch (e) {}
            try { dir = toText(t.focusedTerminal.workingDirectory()); } catch (e) {}
            if (dir === '') {
              try { dir = toText(t.terminals.workingDirectory()[0]); } catch (e) {}
            }
            try { tty = t.terminals.tty().map(toText); } catch (e) {}
            titles.push(title);
            urls.push(dir);
            ids.push(id);
            ttys.push(tty);
          }
          result.push({ id: toText(w.id()), active: active, titles: titles, urls: urls, ids: ids, ttys: ttys });
        } catch (e) {}
      }
      return JSON.stringify(result);
    }
    """

    /// Terminal.app. Tabs have no title of their own over AppleScript: the
    /// selected tab uses the window name, the others their custom title or the
    /// name of the foreground process. The "URL" is filled in from the tty and
    /// processes (and replaced by Claude Code's working directory later).
    /// argv: [bundleID]
    static let fetchTerminalTabs = """
    function run(argv) {
      var app = Application(argv[0]);
      var toText = function (x) { return x === null || x === undefined ? '' : String(x); };
      var base = function (p) { var s = toText(p).replace(/^-/, ''); return s.split('/').pop(); };
      var result = [];
      var wins = app.windows;
      var count = wins.length;
      for (var i = 0; i < count; i++) {
        var w = wins[i];
        try {
          var tabs = w.tabs;
          var n = tabs.length;
          if (n === 0) { continue; }
          var windowName = '';
          try { windowName = toText(w.name()); } catch (e) {}
          var titles = [], urls = [], ids = [], ttys = [];
          var active = 0;
          for (var j = 0; j < n; j++) {
            var t = tabs[j];
            var tty = '', custom = '', procs = [], selected = false;
            try { tty = toText(t.tty()); } catch (e) {}
            try { custom = toText(t.customTitle()); } catch (e) {}
            try { procs = t.processes().map(base).filter(function (p) { return p !== '' && p !== 'login'; }); } catch (e) {}
            try { selected = t.selected(); } catch (e) {}
            if (selected) { active = j + 1; }
            var last = procs.length > 0 ? procs[procs.length - 1] : '';
            var title = selected && windowName !== '' ? windowName : (custom !== '' ? custom : last);
            var shortTTY = tty.replace(/^\/dev\//, '');
            titles.push(title);
            urls.push([shortTTY, procs.join(' > ')].filter(function (x) { return x !== ''; }).join(' \u00b7 '));
            ids.push('');
            ttys.push(tty === '' ? [] : [tty]);
          }
          result.push({ id: toText(w.id()), active: active, titles: titles, urls: urls, ids: ids, ttys: ttys });
        } catch (e) {}
      }
      return JSON.stringify(result);
    }
    """

    /// Common prologue: resolves `w` (window) and `tidx` (tab index) from argv.
    /// argv: [windowID, tabIndex, tabID or ""]
    /// Ghostty's window ids are text, so they are never coerced to a number.
    private static func prologue(_ browser: Browser) -> String {
        let window = browser.kind == .ghostty
            ? "\t\tset w to window id widText\n"
            : """
            \t\ttry
            \t\t\tset w to window id (widText as integer)
            \t\ton error
            \t\t\tset w to window id widText
            \t\tend try

            """
        let head = """
        on run argv
        \tset widText to item 1 of argv
        \tset tidx to (item 2 of argv) as integer
        \tset tidText to item 3 of argv
        \ttell application id "\(browser.bundleID)"

        """
        let findTab = """
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
        return head + window + findTab
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
        case .ghostty:
            body = """
            \t\tselect tab (tab tidx of w)
            \t\tactivate window w
            \t\tactivate

            """
        case .appleTerminal:
            body = """
            \t\ttry
            \t\t\tif miniaturized of w then set miniaturized of w to false
            \t\tend try
            \t\tset selected of tab tidx of w to true
            \t\tset index of w to 1
            \t\tactivate

            """
        }
        return prologue(browser) + body + epilogue
    }

    /// AppleScript that closes the tab, or nil when Taffy doesn't close tabs of
    /// this app. Terminal tabs are never closed from the panel: that would kill
    /// whatever runs in them (Claude Code included).
    static func close(_ browser: Browser) -> String? {
        guard browser.category == .browser else { return nil }
        return prologue(browser) + "\t\tclose tab tidx of w\n" + epilogue
    }
}
