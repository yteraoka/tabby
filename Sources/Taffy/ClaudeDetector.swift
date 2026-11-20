import Foundation

/// Finds terminal tabs that run Claude Code.
///
/// Terminals report each tab's tty, so the reliable way is to look for a
/// `claude` process on that tty with `ps`. When a terminal doesn't report the
/// tty (older Ghostty), the tab title is used instead: Claude Code sets the
/// terminal title while it runs.
enum ClaudeDetector {
    struct ClaudeProcess: Equatable {
        let pid: Int32
        /// "ttys003"
        let tty: String
    }

    /// Returns `tabs` with `claudeCode` set, and the subtitle of Claude Code tabs
    /// replaced by the directory Claude Code runs in (when it can be read).
    static func annotate(_ tabs: [TabItem]) -> [TabItem] {
        guard !tabs.isEmpty else { return tabs }
        let processes = claudeProcesses()
        var pidByTTY: [String: Int32] = [:]
        for process in processes where pidByTTY[process.tty] == nil {
            pidByTTY[process.tty] = process.pid
        }
        let directories = workingDirectories(of: Array(Set(pidByTTY.values)))

        return tabs.map { tab in
            var tab = tab
            if tab.ttys.isEmpty {
                tab.claudeCode = titleLooksLikeClaude(tab.title)
                return tab
            }
            guard let pid = tab.ttys.lazy.compactMap({ pidByTTY[$0] }).first else { return tab }
            tab.claudeCode = true
            if let directory = directories[pid] {
                tab = tab.withURL(abbreviateHome(directory))
            }
            return tab
        }
    }

    /// "/dev/ttys003" -> "ttys003"
    static func shortTTY(_ tty: String) -> String {
        let trimmed = tty.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("/dev/") ? String(trimmed.dropFirst(5)) : trimmed
    }

    /// Whether a command line (`ps -o args`) is Claude Code: `claude ...`,
    /// `/path/to/claude ...`, the native install (`.../claude/versions/2.0.0`),
    /// or the npm package run by node / bun.
    static func isClaudeCommand(_ args: String) -> Bool {
        let words = args.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard let first = words.first else { return false }
        if isClaudeExecutable(first) { return true }
        let runtimes: Set<String> = ["node", "bun", "deno"]
        if runtimes.contains(basename(first)), words.count > 1 {
            // Skip runtime flags such as --no-warnings.
            if let script = words.dropFirst().first(where: { !$0.hasPrefix("-") }) {
                return isClaudeExecutable(script) || script.contains("@anthropic-ai/claude-code")
            }
        }
        return false
    }

    private static func isClaudeExecutable(_ path: String) -> Bool {
        basename(path) == "claude" || path.contains("/claude/versions/")
    }

    private static func basename(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// Parses `ps -axo pid=,tty=,args=`. Processes without a terminal ("??")
    /// are skipped.
    static func parsePS(_ output: String) -> [ClaudeProcess] {
        var result: [ClaudeProcess] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3, let pid = Int32(fields[0]) else { continue }
            let tty = String(fields[1])
            guard tty != "??", tty != "-", isClaudeCommand(String(fields[2])) else { continue }
            // ps shows "s003" for "ttys003" on some systems.
            result.append(ClaudeProcess(pid: pid, tty: tty.hasPrefix("tty") ? tty : "tty" + tty))
        }
        return result
    }

    /// Parses `lsof -Fpn` output ("p123\nfcwd\nn/path\n...").
    static func parseLsof(_ output: String) -> [Int32: String] {
        var result: [Int32: String] = [:]
        var pid: Int32?
        for line in output.split(whereSeparator: \.isNewline) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int32(value)
            case "n": if let pid, result[pid] == nil { result[pid] = value }
            default: break
            }
        }
        return result
    }

    /// Claude Code titles the terminal "✳ <what it is doing>" (with a spinner
    /// in front while it works) or "Claude Code".
    static func titleLooksLikeClaude(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: "claude code", options: .caseInsensitive) != nil { return true }
        guard let first = trimmed.unicodeScalars.first else { return false }
        // ✳ and the braille spinner frames (U+2800–U+28FF).
        return first == "\u{2733}" || (0x2800...0x28FF).contains(first.value)
    }

    static func abbreviateHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    // MARK: - Processes

    private static func claudeProcesses() -> [ClaudeProcess] {
        guard let output = run("/bin/ps", ["-axww", "-o", "pid=,tty=,args="]) else { return [] }
        return parsePS(output)
    }

    private static func workingDirectories(of pids: [Int32]) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let list = pids.map(String.init).joined(separator: ",")
        guard let output = run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-Fpn", "-p", list]) else { return [:] }
        return parseLsof(output)
    }

    /// Runs a command and returns its stdout (also when it exits non-zero:
    /// lsof does that when one of the processes is gone).
    private static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("Taffy: could not run %@: %@", path, error.localizedDescription)
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
