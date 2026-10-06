import Foundation

/// Decides whether a message is about a *subscription* rather than a one-off
/// purchase, and pulls out what the plan looks like.
///
/// Why this exists: the first version of the detector guessed from spending
/// alone — a merchant that charged twice for a similar amount was called a
/// subscription. That is simply not true of normal life. A restaurant visited
/// monthly, a pharmacy, a petrol station and a furniture shop all match that
/// shape, and the page filled up with them while the handful of real
/// subscriptions were buried.
///
/// The evidence that actually separates the two is in the words. A bank alert
/// for a card purchase says nothing about renewing; a subscription receipt
/// almost always says "subscription", "renews", "auto-renew", "billing period"
/// or names a plan. So the decision is made from the message text, with the
/// known-brand catalogue as the other way in.
enum SubscriptionEmailParser {

    // MARK: - Is this about a subscription?

    /// Phrases that only appear when something recurs. Deliberately strict:
    /// a false positive here puts a kebab shop back on the page.
    private static let recurringMarkers = [
        "subscription", "subscriptions", "subscribed",
        "auto-renew", "auto renew", "automatically renew", "automatically renews",
        "will renew", "renews on", "renewal", "renewed",
        "recurring payment", "recurring charge", "recurring billing",
        "billing period", "billing cycle", "next billing", "next payment",
        "membership fee", "membership renewal",
        "your plan", "plan renews", "free trial ends", "trial ends",
        "cancel anytime", "manage your subscription", "manage subscription",
    ]

    /// Phrases that look recurring but are not — a bank's own marketing about
    /// standing orders, or a receipt that merely mentions cancelling an order.
    private static let disqualifiers = [
        "cancel your order", "order cancelled", "order canceled",
        "subscription to our newsletter", "newsletter subscription",
        "unsubscribe from this", "email subscription",
    ]

    static func looksLikeSubscription(_ text: String) -> Bool {
        let lower = text.lowercased()
        if disqualifiers.contains(where: { lower.contains($0) }) { return false }
        return recurringMarkers.contains(where: { lower.contains($0) })
    }

    // MARK: - How often?

    /// Reads the billing period out of the wording, e.g. "Monthly", "per year",
    /// "/mo", "billed annually".
    static func cycle(in text: String) -> BillingCycle? {
        let lower = text.lowercased()

        let yearly  = ["yearly", "annually", "annual", "per year", "/year", "/yr",
                       "a year", "12 months", "1 year"]
        let monthly = ["monthly", "per month", "/month", "/mo", "a month",
                       "1 month", "every month"]
        let weekly  = ["weekly", "per week", "/week", "a week", "every week"]
        let quarter = ["quarterly", "every 3 months", "3 months", "per quarter"]

        // Longest, most specific wording first so "per year" beats "year".
        if yearly.contains(where: { lower.contains($0) })  { return .yearly }
        if quarter.contains(where: { lower.contains($0) }) { return .quarterly }
        if monthly.contains(where: { lower.contains($0) }) { return .monthly }
        if weekly.contains(where: { lower.contains($0) })  { return .weekly }
        return nil
    }

    // MARK: - Apple receipts

    /// True for the receipts Apple sends for anything bought through an Apple
    /// ID — the only way these ever reach the app, since Apple exposes no API
    /// for reading another app's subscriptions.
    static func isAppleReceipt(_ text: String) -> Bool {
        let lower = text.lowercased()
        let fromApple = ["apple.com/bill", "no_reply@email.apple.com",
                         "apple receipt", "receipt from apple", "apple services",
                         "itunes store", "app store"]
        return fromApple.contains(where: { lower.contains($0) })
    }

    /// Pulls the subscribed app out of an Apple receipt.
    ///
    /// Apple's receipts list the item, then the plan, then the renewal date:
    ///
    ///     Disney+ (Monthly)
    ///     Subscription  Renews 14 Oct 2026
    ///     OMR 5.146
    ///
    /// The layout varies by locale and changes over time, so every piece is
    /// optional and anything missing falls back to something sensible rather
    /// than throwing the receipt away.
    static func appleSubscription(from text: String, receivedOn date: Date) -> Subscription? {
        guard isAppleReceipt(text), looksLikeSubscription(text) else { return nil }

        let name = appleAppName(from: text) ?? "Apple Subscription"
        let amount = amountNear(keyword: nil, in: text) ?? 0
        guard amount > 0 else { return nil }

        let period = cycle(in: text) ?? .monthly
        let renewal = renewalDate(in: text)

        // When the receipt names a renewal date, work the schedule back from it
        // so the next due date is the one Apple actually quoted.
        let lastCharged: Date = {
            guard let renewal = renewal else { return date }
            let cal = Calendar.current
            let backOne: Date? = {
                switch period {
                case .weekly:    return cal.date(byAdding: .day,   value: -7, to: renewal)
                case .monthly:   return cal.date(byAdding: .month, value: -1, to: renewal)
                case .quarterly: return cal.date(byAdding: .month, value: -3, to: renewal)
                case .yearly:    return cal.date(byAdding: .year,  value: -1, to: renewal)
                }
            }()
            return backOne ?? date
        }()

        return Subscription(name: name, amount: amount, cycle: period,
                            startedOn: lastCharged, lastChargedOn: lastCharged,
                            isDetected: true)
    }

    /// The app name on an Apple receipt — the line before the word
    /// "Subscription", or a bracketed plan line like "Disney+ (Monthly)".
    private static func appleAppName(from text: String) -> String? {
        let patterns = [
            #"(?m)^\s*([A-Za-z0-9][A-Za-z0-9 .:+&'’\-]{1,40})\s*\((?:monthly|yearly|annual|weekly|quarterly)[^)]*\)"#,
            #"(?i)\b([A-Za-z0-9][A-Za-z0-9 .:+&'’\-]{1,40})\s*[-–—]\s*(?:monthly|yearly|annual)\s+subscription"#,
            #"(?i)subscription\s+(?:to|for)\s+([A-Za-z0-9][A-Za-z0-9 .:+&'’\-]{1,40})"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let m = regex.firstMatch(in: text, range: range),
               let r = Range(m.range(at: 1), in: text) {
                let candidate = String(text[r])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,-–—:"))
                if candidate.count >= 2 { return candidate }
            }
        }
        return nil
    }

    /// Any renewal date the message quotes.
    private static func renewalDate(in text: String) -> Date? {
        let patterns = [
            #"(?i)renew(?:s|ed|al)?(?:\s+on)?\s*[:\-]?\s*(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})"#,
            #"(?i)next\s+(?:billing|payment|charge)(?:\s+date)?\s*[:\-]?\s*(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})"#,
            #"(?i)renew(?:s|ed|al)?(?:\s+on)?\s*[:\-]?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#,
        ]
        let formats = ["d MMM yyyy", "d MMMM yyyy", "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy"]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let m = regex.firstMatch(in: text, range: range),
                  let r = Range(m.range(at: 1), in: text) else { continue }
            let raw = String(text[r])
            for fmt in formats {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = fmt
                if let d = f.date(from: raw) { return d }
            }
        }
        return nil
    }

    /// First currency amount in the message, optionally near a keyword.
    private static func amountNear(keyword: String?, in text: String) -> Double? {
        let currency = #"(?:rs\.?|inr|₹|omr|aed|sar|usd|\$|eur|€|gbp|£|kwd|bhd|qar)"#
        let pattern = currency + #"\s*([0-9,]+(?:\.[0-9]{1,3})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { return nil }
        let ns = text as NSString
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let r = Range(m.range(at: 1), in: text) else { continue }
            let digits = String(text[r]).replacingOccurrences(of: ",", with: "")
            if let v = Double(digits), v > 0 { return v }
        }
        return nil
    }
}
