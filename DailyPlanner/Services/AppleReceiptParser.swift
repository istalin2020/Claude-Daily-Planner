import Foundation

/// One line of an Apple receipt.
struct AppleReceiptItem: Equatable {
    /// The app, when the receipt names it. The newer invoice layout does
    /// ("X" above "X Premium"); the older one only names the plan.
    var appName: String?
    /// The plan or in-app purchase, e.g. "Pro Monthly Plan", "SuperGrok".
    var planName: String
    var cycle: BillingCycle
    var amount: Double
    var currencyCode: String
    var renewal: Date
    /// The app's real icon, served by Apple's own CDN inside the receipt.
    var iconURL: String?
    /// The Apple Account the purchase belongs to. With Family Sharing the
    /// organiser receives every member's receipts, so this is often not the
    /// user's own address.
    var accountEmail: String?

    /// Stable id for the app behind this line, taken from its icon. Lets an
    /// older receipt that only names the plan be matched to the app a newer
    /// receipt named.
    var iconKey: String? { iconURL.flatMap(AppleReceiptParser.iconKey(from:)) }
}

/// Reads Apple receipts from their HTML, by structure.
///
/// Written against the user's real mailbox, which holds three layouts:
///
/// * **Modern tax invoice** — `<tr class="subscription-lockup">` with the app,
///   then the plan and period, then "Renews 2 November 2026", then the price.
/// * **Legacy invoice** — `<td class="item-cell">` with `span.title` (the plan,
///   never the app), `span.addon-duration`, `span.renewal`; price "₹ 79". The
///   whole receipt is repeated for desktop and mobile, and one invoice can
///   carry several items.
/// * **Receipt for Apple services** — the legacy layout again, used for things
///   like "₹ 2,000 Add Funds to Apple Account".
///
/// Only a line with a renewal date is a subscription. Top-ups and one-off app
/// purchases have none, and every Apple receipt's footer mentions
/// "subscription renewals" — which is exactly how a ₹2,000 wallet top-up had
/// been listed as a subscription.
enum AppleReceiptParser {

    /// True when the HTML is an Apple invoice of either layout.
    static func isInvoice(_ html: String) -> Bool {
        html.contains("subscription-lockup") || html.contains("class=\"item-cell")
    }

    static func items(html: String) -> [AppleReceiptItem] {
        let account = accountEmail(in: html)
        var found = modernItems(html) + legacyItems(html)
        for i in found.indices where found[i].accountEmail == nil {
            found[i].accountEmail = account
        }
        return found
    }

    // MARK: - Modern layout

    private static func modernItems(_ html: String) -> [AppleReceiptItem] {
        var result: [AppleReceiptItem] = []
        for row in captures(#"(?s)<tr[^>]*class="[^"]*subscription-lockup(?!__)[^"]*"[^>]*>(.*?)</tr>"#, in: html) {
            let texts = captures(#"(?s)<p[^>]*>(.*?)</p>"#, in: row).map(plainText).filter { !$0.isEmpty }
            guard let renewIdx = texts.firstIndex(where: { $0.lowercased().hasPrefix("renews") }),
                  let renewal = parseDate(String(texts[renewIdx].dropFirst("renews".count))),
                  let planIdx = texts.firstIndex(where: { $0.contains("(") }),
                  let (amount, code) = texts.lazy.compactMap(priceOnly).first
            else { continue }

            let planLine = texts[planIdx]
            let app = planIdx > 0 ? texts[planIdx - 1] : nil
            result.append(AppleReceiptItem(
                appName: app.flatMap(usableName),
                planName: stripPeriods(planLine),
                cycle: period(in: planLine) ?? .monthly,
                amount: amount, currencyCode: code, renewal: renewal,
                iconURL: appIcon(in: row), accountEmail: nil))
        }
        return result
    }

    // MARK: - Legacy layout

    private static func legacyItems(_ html: String) -> [AppleReceiptItem] {
        // The receipt is printed twice, for desktop and for mobile. Read the
        // desktop copy only, or every plan would be counted twice.
        var scope = html
        // Match the class attribute itself: both names also appear earlier,
        // in the email's CSS.
        if let start = html.range(of: "class=\"aapl-desktop-div\""),
           let end = html.range(of: "class=\"aapl-mobile-div\"", range: start.upperBound..<html.endIndex) {
            scope = String(html[start.upperBound..<end.lowerBound])
        }

        var result: [AppleReceiptItem] = []
        let pattern = #"(?s)class="artwork-cell[^"]*"[^>]*>(.*?)</td>\s*<td[^>]*class="item-cell[^"]*"[^>]*>(.*?)</td>\s*<td[^>]*class="price-cell[^"]*"[^>]*>(.*?)</td>"#
        for groups in captureGroups(pattern, in: scope) where groups.count == 3 {
            let art = groups[0], item = groups[1], price = groups[2]
            guard let title = spanText("title", in: item),
                  let renewText = spanText("renewal", in: item),
                  let renewal = parseDate(renewText.replacingOccurrences(of: "Renews", with: "")),
                  let priceText = captures(#"(?s)<span[^>]*>(.*?)</span>"#, in: price).first.map(plainText),
                  let (amount, code) = priceOnly(priceText)
            else { continue }

            let duration = spanText("addon-duration", in: item) ?? ""
            result.append(AppleReceiptItem(
                appName: nil,
                planName: title,
                cycle: period(in: duration) ?? period(in: title) ?? .monthly,
                amount: amount, currencyCode: code, renewal: renewal,
                iconURL: appIcon(in: art), accountEmail: nil))
        }
        return result
    }

    // MARK: - Fields

    private static func accountEmail(in html: String) -> String? {
        let text = plainText(html)
        let pattern = #"(?i)apple account:?\s*([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})"#
        return captures(pattern, in: text).first?.lowercased()
    }

    /// The app's icon. Apple's generic artwork (used for its own services and
    /// wallet top-ups) lives under s.mzstatic.com/email and isn't an app icon.
    private static func appIcon(in fragment: String) -> String? {
        captures(#"<img[^>]*src="(https://is\d+-ssl\.mzstatic\.com/[^"]+)""#, in: fragment).first
    }

    static func iconKey(from url: String) -> String? {
        captures(#"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"#, in: url).first
    }

    private static func spanText(_ cls: String, in html: String) -> String? {
        let pattern = #"(?s)<span[^>]*class="[^"]*\b"# + cls + #"\b[^"]*"[^>]*>(.*?)</span>"#
        return captures(pattern, in: html).first.map(plainText).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// "X Premium (Monthly) (Monthly)" → "X Premium"
    static func stripPeriods(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Reads "(Monthly)", "(Annual)", "(3 months)", "(1 month)", "(1 week)".
    static func period(in s: String) -> BillingCycle? {
        let l = s.lowercased()
        if l.contains("annual") || l.contains("yearly") || l.contains("1 year") || l.contains("12 month") { return .yearly }
        if l.contains("3 month") || l.contains("quarterly") { return .quarterly }
        if l.contains("week") { return .weekly }
        if l.contains("month") { return .monthly }
        return nil
    }

    /// A text that is only a price: "₹470.00", "₹ 79", "₹ 2,000", "$9.99".
    static func priceOnly(_ s: String) -> (Double, String)? {
        let pattern = #"^\s*(₹|Rs\.?|INR|\$|US\$|USD|€|EUR|£|GBP|OMR|AED|SAR)\s*([0-9][0-9,]*(?:\.[0-9]{1,3})?)\s*$"#
        guard let g = captureGroups(pattern, in: s).first, g.count == 2,
              let v = Double(g[1].replacingOccurrences(of: ",", with: "")), v > 0 else { return nil }
        switch g[0].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) {
        case "₹", "rs", "inr":        return (v, "INR")
        case "$", "us$", "usd":       return (v, "USD")
        case "€", "eur":              return (v, "EUR")
        case "£", "gbp":              return (v, "GBP")
        default:                      return (v, g[0].uppercased())
        }
    }

    /// The modern layout prints the plan's name where the app would be for a
    /// handful of apps ("Monthly" above "Monthly (Monthly)").
    private static func usableName(_ s: String) -> String? {
        let l = s.lowercased()
        let notNames: Set<String> = ["monthly", "yearly", "annual", "weekly", "quarterly",
                                     "subscription", "app store", "apple services"]
        return (s.isEmpty || notNames.contains(l)) ? nil : s
    }

    static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for fmt in ["d MMMM yyyy", "d MMM yyyy", "MMM d, yyyy", "MMMM d, yyyy", "d MMM, yyyy"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_GB")
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        // Apple writes "Sept" in British English, which DateFormatter rejects.
        if s.contains("Sept") { return parseDate(s.replacingOccurrences(of: "Sept", with: "Sep")) }
        return nil
    }

    // MARK: - Text helpers

    static func plainText(_ html: String) -> String {
        var s = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        for (entity, char) in [("&amp;", "&"), ("&nbsp;", " "), ("&#39;", "'"), ("&quot;", "\""),
                               ("&lt;", "<"), ("&gt;", ">"), ("&#8377;", "₹")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func captures(_ pattern: String, in text: String) -> [String] {
        captureGroups(pattern, in: text).compactMap(\.first)
    }

    private static func captureGroups(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (1..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }
}
