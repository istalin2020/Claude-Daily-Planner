import Foundation

/// Something a subscription email tells us happened.
enum SubscriptionEvent {
    /// A plan was paid for or renewed. Amount is in `currencyCode`, which the
    /// view model converts to the user's currency before storing.
    case charged(Subscription)
    /// A plan was cancelled on the service's own website or app. Carries the
    /// same identity fields as a charge so it lands on the same row.
    case cancelled(Subscription, on: Date)

    var date: Date {
        switch self {
        case .charged(let sub):         return sub.lastChargedOn
        case .cancelled(_, let on):     return on
        }
    }
}

/// Reads subscription receipts and cancellation notices.
///
/// The rules this enforces were learned the hard way:
///
/// * **Repetition is not evidence.** A restaurant visited monthly charges the
///   same amount on the same rhythm as Netflix. Only the words decide.
/// * **A receipt is evidence, not an expense.** The bank alert for a charge is
///   the expense — money moved. The merchant's receipt for that same charge is
///   what tells us it was a subscription, at what cycle, renewing when. Booking
///   both as expenses double-counts every subscription, because the duplicate
///   guard cannot match a USD receipt to an OMR bank alert to the baisa.
/// * **The sender is the strongest signal.** "OpenAI <noreply@tm.openai.com>"
///   names the service outright; the body often mentions other brands ("Pay
///   with Apple Pay", "Download on the App Store") that would mislead.
/// * **Words that look recurring often aren't.** Marketing ("subscribe now"),
///   failed payments and cancellations all say "subscription" without a plan
///   having been paid for.
enum SubscriptionEmailParser {

    // MARK: - Vocabulary

    /// Phrases that only appear when something recurs. Bank-side wording for
    /// standing payments (autopay, e-mandate) is included because some banks —
    /// in India especially — say so in the alert itself.
    private static let recurringMarkers = [
        "subscription", "subscriptions", "subscribed", "membership",
        "auto-renew", "auto renew", "autorenew", "automatically renew",
        "will renew", "renews on", "renews ", "renewal", "renewed",
        "recurring payment", "recurring charge", "recurring billing",
        "billing period", "billing cycle", "next billing", "next payment",
        "your plan", "plan renews", "free trial ends", "trial ends",
        "autopay", "auto-pay", "auto debit", "e-mandate", "emandate",
        "nach mandate", "standing instruction",
    ]

    /// Evidence that money actually changed hands, as opposed to an offer.
    private static let paidMarkers = [
        "receipt", "amount paid", "paid", "charged", "payment received",
        "payment successful", "payment confirmation", "invoice", "renewed",
        "billed", "thank you for your payment", "order total", "debited",
        "tax invoice", "order placed", "purchase", "subscription confirmed",
        "confirms your subscription",
    ]

    /// Notices that a plan has stopped.
    private static let cancelMarkers = [
        "has been cancelled", "has been canceled", "was cancelled", "was canceled",
        "subscription cancelled", "subscription canceled",
        "cancellation confirmed", "cancellation confirmation",
        "you've cancelled", "you've canceled", "you have cancelled", "you have canceled",
        "won't be charged again", "will not be charged again",
        "will not renew", "won't renew", "auto-renewal is off", "auto-renew is off",
        "turned off auto-renew", "membership has ended", "subscription has ended",
        "subscription has expired",
    ]

    /// Recurring-sounding mail that records nothing that happened.
    private static let notAnEvent = [
        // failed or pending payments
        "payment failed", "payment was declined", "was declined", "payment declined",
        "unable to process", "couldn't process", "could not process",
        "update your payment", "payment method has expired",
        // the user's own inbox housekeeping
        "subscription to our newsletter", "newsletter subscription",
        "email subscription", "unsubscribe from this", "cancel your order",
        "order cancelled", "order canceled",
        // offers and nudges
        "subscribe now", "start your free trial", "try it free", "special offer",
        "limited time", "% off", "upgrade now", "upgrade to", "get premium",
        "come back", "we miss you", "rejoin",
        // shareholder mail: a dividend notice quotes an amount and a date,
        // which made an Indian Energy Exchange dividend of ₹2 a "yearly plan"
        "dividend", "record date", "annual general meeting", "e-voting",
        "shareholder", "intimation of payment",
        // research-subscription promotions carry this disclaimer on every mail;
        // Equitymaster's showed a made-up ₹10,60,000 "subscription"
        "investment in securities market are subject to market risks",
        "save you thousands",
    ]

    /// What only a real receipt says. Required for anything not from Apple:
    /// promotions talk about subscriptions and quote prices too, but never
    /// that an amount was paid.
    private static let receiptEvidence = [
        "receipt", "invoice", "amount paid", "amount charged", "payment received",
        "payment successful", "payment confirmation", "thank you for your payment",
        "has been renewed", "was renewed", "renewal confirmation", "order confirmation",
        "subscription confirmed", "confirms your subscription", "you've been charged",
        "you have been charged", "we've charged", "has been charged",
    ]

    // MARK: - Public checks

    /// True when a message talks about something recurring. Used on bank
    /// alerts at import, which is how an autopay or e-mandate debit gets
    /// recognised as a subscription without any receipt.
    static func looksLikeSubscription(_ text: String) -> Bool {
        let lower = text.lowercased()
        if notAnEvent.contains(where: { lower.contains($0) }) { return false }
        return recurringMarkers.contains(where: { lower.contains($0) })
    }

    /// True when the email comes from a bank. Its debits are expenses, never
    /// receipts — even an alert that says "e-mandate" is still the money moving.
    ///
    /// Judged from the sender only: the body of a merchant receipt routinely
    /// mentions banks and cards, and several bank short-names ("citi", "fab",
    /// "bob") occur inside ordinary words.
    static func isFromBank(sender: String) -> Bool {
        let s = sender.lowercased()
        if s.contains("bank") { return true }
        let shortNames = ["sbi", "hdfc", "icici", "axis", "kotak", "hsbc", "citi",
                          "nbo", "dbs", "ocbc", "uob", "enbd", "adcb", "mashreq",
                          "alrajhi", "al rajhi", "snb", "fab", "bankdhofar", "oab"]
        return shortNames.contains { name in
            s.range(of: #"(?<![a-z0-9])"# + NSRegularExpression.escapedPattern(for: name)
                        + #"(?![a-z0-9])"#, options: .regularExpression) != nil
        }
    }

    /// Reads one email into whatever it says happened — usually nothing, one
    /// event for most receipts, several for an Apple invoice carrying more
    /// than one plan.
    ///
    /// - Parameters:
    ///   - html: the HTML part, when there is one. Apple invoices are read from
    ///     their structure rather than flattened text.
    ///   - recipients: the To header. With Family Sharing, a member's renewal
    ///     notice goes to them and to the organiser, so the other address is
    ///     whose plan it is.
    static func events(body: String, html: String, sender: String, subject: String,
                       recipients: String, receivedOn date: Date) -> [SubscriptionEvent] {
        // Bank alerts are expenses, handled by BankSMSParser.
        guard !isFromBank(sender: sender) else { return [] }

        let lower = (subject + "\n" + body).lowercased()
        if isFromApple(sender: sender, lowerBody: lower) {
            if AppleReceiptParser.isInvoice(html) {
                return AppleReceiptParser.items(html: html).map(charged(from:))
            }
            // Confirmations, renewal reminders and cancellations come from
            // Apple's transactional address. Its marketing ("3 months of Apple
            // Music free") comes from elsewhere and talks about subscriptions.
            guard sender.lowercased().contains("email.apple.com") else { return [] }
            return appleNotice(body: body, subject: subject,
                               recipients: recipients, receivedOn: date).map { [$0] } ?? []
        }
        return otherReceipt(body: body, sender: sender, subject: subject,
                            receivedOn: date).map { [$0] } ?? []
    }

    private static func charged(from item: AppleReceiptItem) -> SubscriptionEvent {
        let last = item.cycle.advance(item.renewal, by: -1)
        var sub = Subscription(name: item.appName ?? item.planName, amount: item.amount,
                               currencyCode: item.currencyCode, cycle: item.cycle,
                               startedOn: last, lastChargedOn: last, isDetected: true)
        sub.viaApple = true
        sub.planName = item.planName
        sub.iconURL = item.iconURL
        sub.accountEmail = item.accountEmail
        sub.nameIsPlanOnly = item.appName == nil
        return .charged(sub)
    }

    /// "Subscription Confirmed", "Your Subscription Renewal" and cancellation
    /// notices: flattened text, labelled fields.
    private static func appleNotice(body: String, subject: String, recipients: String,
                                    receivedOn date: Date) -> SubscriptionEvent? {
        let combined = subject + "\n" + body
        let lower = combined.lowercased()
        guard recurringMarkers.contains(where: { lower.contains($0) }) else { return nil }

        var app = appleAppName(from: combined)
        // Renewal reminders print the app, then "<app> Plan" as a heading:
        //     ChatGPT
        //     ChatGPT Plan
        //     ChatGPT Go (1 month)
        if let a = app, a.hasSuffix(" Plan") {
            let base = String(a.dropLast(" Plan".count))
            let lines = combined.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if lines.contains(base) { app = base }
        }
        let plan = applePlanName(from: combined)
        guard let name = app ?? plan else { return nil }

        var sub = Subscription(name: name, amount: 0, cycle: cycle(in: combined) ?? .monthly,
                               startedOn: date, lastChargedOn: date, isDetected: true)
        sub.viaApple = true
        sub.planName = plan
        sub.nameIsPlanOnly = app == nil
        sub.accountEmail = recipients.lowercased()

        if cancelMarkers.contains(where: { lower.contains($0) }) {
            return .cancelled(sub, on: date)
        }

        // A confirmation or a "will renew soon" reminder: the plan is running.
        let running = ["confirms your subscription", "subscription confirmed",
                       "automatically renews", "will renew soon", "subscription renewal"]
        guard running.contains(where: { lower.contains($0) }),
              let (amount, currency) = chargedAmount(in: combined) else { return nil }
        sub.amount = amount
        sub.currencyCode = currency
        if let renewal = renewalDate(in: combined) {
            sub.lastChargedOn = sub.cycle.advance(renewal, by: -1)
            sub.startedOn = sub.lastChargedOn
        }
        return .charged(sub)
    }

    /// Everything that isn't Apple: a service's own receipt or cancellation.
    private static func otherReceipt(body: String, sender: String, subject: String,
                                     receivedOn date: Date) -> SubscriptionEvent? {
        let combined = subject + "\n" + body
        let lower = combined.lowercased()

        if notAnEvent.contains(where: { lower.contains($0) }) { return nil }
        if BankSMSParser.isMarketing(lower) { return nil }
        guard recurringMarkers.contains(where: { lower.contains($0) }) else { return nil }
        guard let name = serviceName(sender: sender, subject: subject,
                                     body: body, viaApple: false) else { return nil }

        var sub = Subscription(name: name, amount: 0, cycle: cycle(in: combined) ?? .monthly,
                               startedOn: date, lastChargedOn: date, isDetected: true)

        // Checked before charges: a cancellation notice commonly says
        // "you won't be charged again", which would otherwise read as a charge.
        if cancelMarkers.contains(where: { lower.contains($0) }) {
            return .cancelled(sub, on: date)
        }

        guard receiptEvidence.contains(where: { lower.contains($0) }) else { return nil }
        guard let (amount, currency) = chargedAmount(in: combined), amount > 0 else { return nil }
        sub.amount = amount
        sub.currencyCode = currency
        if let renewal = renewalDate(in: combined) {
            sub.lastChargedOn = sub.cycle.advance(renewal, by: -1)
            sub.startedOn = sub.lastChargedOn
        }
        return .charged(sub)
    }

    // MARK: - Cycle

    /// Reads the billing period out of the wording, most specific first.
    static func cycle(in text: String) -> BillingCycle? {
        let lower = text.lowercased()
        let yearly  = ["yearly", "annually", "annual", "per year", "/year", "/yr",
                       "a year", "12 months", "1 year"]
        let quarter = ["quarterly", "every 3 months", "3 months", "per quarter"]
        let monthly = ["monthly", "per month", "/month", "/mo", "a month",
                       "1 month", "every month"]
        let weekly  = ["weekly", "per week", "/week", "every week"]

        if yearly.contains(where: { lower.contains($0) })  { return .yearly }
        if quarter.contains(where: { lower.contains($0) }) { return .quarterly }
        if monthly.contains(where: { lower.contains($0) }) { return .monthly }
        if weekly.contains(where: { lower.contains($0) })  { return .weekly }
        return nil
    }

    // MARK: - Who

    /// The plan on an Apple notice: the labelled "Subscription" field on a
    /// confirmation, otherwise the line carrying the period, e.g.
    /// "ChatGPT Go (1 month)" → "ChatGPT Go".
    private static func applePlanName(from text: String) -> String? {
        let patterns = [
            #"(?m)^[ \t]*Subscription[ \t]*[:\t ][ \t]*([^\n]{2,40})$"#,
            #"(?im)^[ \t]*([^\n(]{2,40}?)[ \t]*\((?:monthly|yearly|annual|weekly|quarterly|\d+\s*(?:month|year|week)s?)\)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for m in regex.matches(in: text, range: range) {
                guard let r = Range(m.range(at: 1), in: text) else { continue }
                let c = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isUsableName(c) { return c }
            }
        }
        return nil
    }

    private static func isFromApple(sender: String, lowerBody: String) -> Bool {
        let s = sender.lowercased()
        return s.contains("@apple.com") || s.contains(".apple.com")
            || lowerBody.contains("apple.com/bill")
            || lowerBody.contains("receipt from apple")
    }

    /// Works out which service the email is about.
    ///
    /// Apple receipts name the app in the body, since Apple is only the seller.
    /// Everything else is identified from the sender and subject — never the
    /// body, which mentions other brands too freely.
    private static func serviceName(sender: String, subject: String,
                                    body: String, viaApple: Bool) -> String? {
        if viaApple {
            if let app = appleAppName(from: subject + "\n" + body) {
                return SubscriptionBrand.canonicalName(app)
            }
            // Apple's tax-invoice receipt does not name the app in text at
            // all — only its icon does — so there is nothing better to call
            // it. The user can rename it; the match key survives a rename.
            return "App Store subscription"
        }

        if let brand = SubscriptionBrand.match(sender + " " + subject) {
            return brand.name
        }

        let (display, domain) = splitSender(sender)
        if let cleaned = cleanDisplayName(display), cleaned.count >= 2 {
            return cleaned
        }
        if let label = registrableLabel(of: domain) {
            return label.prefix(1).uppercased() + label.dropFirst()
        }
        return nil
    }

    /// "OpenAI <noreply@tm.openai.com>" → ("OpenAI", "tm.openai.com")
    private static func splitSender(_ sender: String) -> (String, String) {
        let trimmed = sender.trimmingCharacters(in: .whitespaces)
        if let lt = trimmed.firstIndex(of: "<"), let gt = trimmed.lastIndex(of: ">"), lt < gt {
            let display = String(trimmed[..<lt])
                .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            let address = String(trimmed[trimmed.index(after: lt)..<gt])
            return (display, address.split(separator: "@").last.map(String.init) ?? "")
        }
        return ("", trimmed.split(separator: "@").last.map(String.init) ?? "")
    }

    /// Drops the billing-department noise senders wrap their name in.
    private static func cleanDisplayName(_ raw: String) -> String? {
        let noise: Set<String> = ["billing", "receipts", "receipt", "payments", "payment",
                                  "team", "support", "noreply", "no-reply", "notifications",
                                  "notification", "invoice", "invoices", "accounts",
                                  "account", "inc", "inc.", "llc", "ltd", "ltd.", "pbc",
                                  "the", "from", "via", "orders", "customer", "service"]
        let words = raw.split(whereSeparator: { " ,|-".contains($0) })
            .map(String.init)
            .filter { !noise.contains($0.lowercased()) }
        let joined = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? nil : joined
    }

    /// "mail.figma.com" → "figma"
    private static func registrableLabel(of domain: String) -> String? {
        let labels = domain.lowercased().split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return nil }
        let label = labels[labels.count - 2]
        return label.count >= 2 ? label : nil
    }

    /// The app on an Apple email, from the two layouts Apple actually sends.
    ///
    /// "Your Subscription is Confirmed" labels it outright:
    ///
    ///     App           WhatsApp Messenger
    ///     Subscription  Whatsapp Plus
    ///
    /// "Your receipt from Apple" (the tax invoice) prints the plan twice —
    /// "Monthly" then "Monthly (Monthly)" — and leaves the app to its icon.
    /// A captured name that is only a billing word is therefore rejected
    /// rather than shown as a subscription called "Monthly".
    private static func appleAppName(from text: String) -> String? {
        let patterns = [
            // Labelled field, value on the same line or the next.
            #"(?m)^[ \t]*App[ \t]*[:\t ][ \t]*([^\n]{2,40})$"#,
            #"(?m)^[ \t]*App[ \t]*:?[ \t]*\n[ \t]*([^\n]{2,40})$"#,
            // Cancellation and expiry notices.
            #"(?i)subscription\s+(?:to|for)\s+([A-Za-z0-9][A-Za-z0-9 .:+&'’\-]{1,40}?)(?:\s+(?:has|was|will|is)\b|[.,\n])"#,
            // The receipt prints the app, then its plan with the period in
            // brackets, so the app is the line above:
            //     iCloud+
            //     iCloud+ with 2 TB of storage (Monthly)
            #"(?im)^[ \t]*([^\n(]{1,40}?)[ \t]*\n[^\n]*\((?:monthly|yearly|annual|weekly|quarterly|\d+\s*(?:month|year|week)s?)[^)]*\)"#,
            // Otherwise the plan line itself: "Disney+ (Monthly)".
            #"(?im)^\s*([A-Za-z0-9][A-Za-z0-9 .:+&'’\-]{1,40}?)\s*\((?:monthly|yearly|annual|weekly|quarterly|\d+\s*(?:month|year|week)s?)[^)]*\)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for m in regex.matches(in: text, range: range) {
                guard let r = Range(m.range(at: 1), in: text) else { continue }
                let candidate = String(text[r])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,-–—:"))
                if isUsableName(candidate) { return candidate }
            }
        }
        return nil
    }

    /// Rejects captures that are a billing period or a label, not a name.
    private static func isUsableName(_ name: String) -> Bool {
        // A single character is allowed: "X" is a real app.
        guard !name.isEmpty, name.rangeOfCharacter(from: .alphanumerics) != nil else { return false }
        let lower = name.lowercased()
        let notNames: Set<String> = ["monthly", "yearly", "annual", "annually", "weekly",
                                     "quarterly", "subscription", "plan", "store",
                                     "app store", "premium", "renewal", "1 month",
                                     "1 year", "trial"]
        if notNames.contains(lower) { return false }
        if lower.hasPrefix("store") || lower.hasPrefix("account") { return false }
        // A line that is only a period in brackets, e.g. "Monthly (Monthly)".
        if lower.range(of: #"^(monthly|yearly|annual|weekly)\b"#,
                       options: .regularExpression) != nil { return false }
        return true
    }

    // MARK: - When

    private static func renewalDate(in text: String) -> Date? {
        let date = #"(\d{1,2}\s+[A-Za-z]{3,9},?\s+\d{4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#
        let patterns = [
            #"(?i)renew(?:s|al)?(?:\s+(?:on|date))?\s*[:\-]?\s*"# + date,
            #"(?i)next\s+(?:billing|payment|charge|renewal)(?:\s+date)?\s*(?:is|on)?\s*[:\-]?\s*"# + date,
            #"(?i)renews?[^.\n]{0,60}?starting\s+(?:on\s+)?"# + date,
            #"(?i)trial[^.\n]{0,60}?ending\s+on\s+"# + date,
            #"(?i)starting\s+(?:from|on)\s+"# + date,
        ]
        let formats = ["d MMM yyyy", "d MMMM yyyy", "d MMM, yyyy", "d MMMM, yyyy",
                       "MMM d, yyyy", "MMMM d, yyyy", "MMM d yyyy", "MMMM d yyyy",
                       "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "dd/MM/yy"]
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

    // MARK: - How much

    private static let currencyToken =
        #"(rs\.?|inr|₹|omr|aed|sar|usd|us\$|\$|eur|€|gbp|£|kwd|bhd|qar)"#

    /// The amount actually charged: a labelled total wins, otherwise the first
    /// amount in the message. Returns the amount and its ISO currency code.
    private static func chargedAmount(in text: String) -> (Double, String)? {
        let number = #"([0-9][0-9,]*(?:\.[0-9]{1,3})?)"#
        // Whole words only — "Subtotal ₹338.14" is the pre-tax figure on an
        // Apple receipt, and matching it as "total" recorded the wrong amount.
        let labels = #"(?i)\b(?:amount paid|amount charged|total charged|total paid|order total|grand total|total|amount|renewal price|price)\s*[:\-]?\s*"#
        let candidates = [
            labels + currencyToken + #"\s*"# + number,      // Total: USD 20.00
            labels + number + #"\s*"# + currencyToken,      // Total: 20.00 USD
            "(?i)" + currencyToken + #"\s*"# + number,      // first $20.00 anywhere
            "(?i)" + number + #"\s*"# + currencyToken,      // first 20.00 OMR anywhere
        ]
        for (i, pattern) in candidates.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for m in regex.matches(in: text, range: range) {
                let curGroup = (i % 2 == 0) ? 1 : 2
                let numGroup = (i % 2 == 0) ? 2 : 1
                guard let cr = Range(m.range(at: curGroup), in: text),
                      let nr = Range(m.range(at: numGroup), in: text) else { continue }
                let digits = String(text[nr]).replacingOccurrences(of: ",", with: "")
                if let value = Double(digits), value > 0 {
                    return (value, isoCode(for: String(text[cr])))
                }
            }
        }
        return nil
    }

    private static func isoCode(for token: String) -> String {
        switch token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) {
        case "$", "us$", "usd": return "USD"
        case "₹", "rs", "inr":  return "INR"
        case "€", "eur":        return "EUR"
        case "£", "gbp":        return "GBP"
        default:                return token.uppercased()
        }
    }
}
