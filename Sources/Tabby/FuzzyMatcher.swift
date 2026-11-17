import Foundation

/// Scores tabs against a whitespace separated query. Every token must match
/// the title, URL or browser name; substring matches rank above fuzzy
/// (subsequence) matches, and title matches rank above URL matches.
enum FuzzyMatcher {
    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func tokens(_ query: String) -> [String] {
        normalize(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func score(_ item: TabItem, tokens: [String]) -> Int? {
        var total = 0
        for token in tokens {
            var best = 0
            if let r = item.searchTitle.range(of: token) {
                var s = 100
                if r.lowerBound == item.searchTitle.startIndex {
                    s += 50
                } else if isWordBoundary(item.searchTitle, before: r.lowerBound) {
                    s += 25
                }
                best = s
            }
            if best == 0, let r = item.searchURL.range(of: token) {
                best = isWordBoundary(item.searchURL, before: r.lowerBound) ? 70 : 60
            }
            if best == 0, item.searchBrowser.contains(token) {
                best = 30
            }
            if best == 0, let s = subsequenceScore(token, in: item.searchTitle) {
                best = s
            }
            if best == 0, subsequenceScore(token, in: item.searchURL) != nil {
                best = 5
            }
            if best == 0 { return nil }
            total += best
        }
        return total
    }

    private static func isWordBoundary(_ s: String, before index: String.Index) -> Bool {
        guard index > s.startIndex else { return true }
        let prev = s[s.index(before: index)]
        return !(prev.isLetter || prev.isNumber)
    }

    /// Returns a score in 1...40 when every character of `needle` appears in
    /// `hay` in order; fewer gaps between matched characters score higher.
    private static func subsequenceScore(_ needle: String, in hay: String) -> Int? {
        var it = hay.makeIterator()
        var gaps = 0
        var started = false
        for nc in needle {
            var found = false
            while let hc = it.next() {
                if hc == nc {
                    found = true
                    started = true
                    break
                }
                if started { gaps += 1 }
            }
            if !found { return nil }
        }
        return max(1, 40 - gaps)
    }
}
