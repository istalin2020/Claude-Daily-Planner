import Foundation

// MARK: - Record

/// One thing an Apple email said about an App Store subscription.
///
/// Records are kept, not applied: the list of App Store subscriptions is
/// worked out from all of them together every time. A single email can't say
/// whether a plan is still running — a renewal reminder promises a charge
/// that may never come, a receipt says nothing about a cancellation made the
/// next day — so no single email is allowed to decide.
struct AppStoreRecord: Codable, Equatable {
    enum Kind: String, Codable {
        /// "Your receipt from Apple": money was taken. `renewal` is when it
        /// renews next. The only kind that counts as a payment.
        case receipt
        /// "Your Subscription is Confirmed". `renewal` is the first charge,
        /// after any free trial.
        case confirmed
        /// "Your Subscription Renewal": it *will* renew on `renewal`. A
        /// promise, not a payment — a family member's Sony LIV reminder was
        /// followed by no charge at all, because they had cancelled.
        case renewalNotice
        /// "Your Subscription is Expiring": the subscriber cancelled. It runs
        /// until `renewal` and then stops.
        case expiring
        /// A credit note: the charge was refunded.
        case refund
        /// The service's own "your subscription has been cancelled" email,
        /// e.g. from Wispr Flow rather than from Apple.
        case vendorCancel
    }

    var kind: Kind
    /// When the email arrived.
    var date: Date
    /// The Apple Account (receipts) or the To line (notices). Whose plan it is
    /// is worked out from this against the user's own address.
    var account: String? = nil
    /// The app as printed, e.g. "Wispr Flow: AI Voice Keyboard".
    var app: String? = nil
    /// The plan, e.g. "Pro Monthly Plan".
    var plan: String? = nil
    var amount: Double? = nil
    var currency: String? = nil
    var cycle: BillingCycle? = nil
    var renewal: Date? = nil
    var iconURL: String? = nil
    /// Apple's subscription-group id, from the "review your subscription"
    /// link every notice carries (`familyId=21737397`). The same for every
    /// notice about one subscription, whatever the app happens to be called.
    var groupID: String? = nil

    /// Identity for de-duplication: the same email read twice, by the regular
    /// sync and by a full scan, must count once.
    var signature: String {
        let day = Int(date.timeIntervalSince1970 / 60)
        let amt = amount.map { String(format: "%.2f", $0) } ?? "-"
        return [kind.rawValue, account ?? "", app ?? "", plan ?? "", amt, String(day)]
            .joined(separator: "|").lowercased()
    }
}

// MARK: - Notices

/// Reads Apple's subscription notices — Confirmed, Renewal, Expiring — from
/// their HTML.
///
/// The Renewal and Expiring notices share one layout. Its header block lists,
/// one per line:
///
///     Wispr Flow: AI Voice Keyboard      ← the app
///     Flow Pro                           ← the subscription group
///                                        ← (often empty)
///     Pro Monthly Plan (1 month)         ← the plan and period
///     ₹400.00/month                      ← the price
///
/// The group line is why one plan used to appear twice: read as the app, it
/// made "Flow Pro" next to Wispr Flow, "B612 VIP Subscription" next to B612,
/// "Family" next to Apple One. The Confirmed notice instead labels its
/// fields ("App", "Subscription", "Content Provider", "Renewal Price").
enum AppleNoticeParser {

    static func record(html: String, subject: String, recipients: String,
                       receivedOn date: Date) -> AppStoreRecord? {
        let s = subject.lowercased()
        let kind: AppStoreRecord.Kind
        if s.contains("expiring") || s.contains("expired") { kind = .expiring }
        else if s.contains("renewal")                      { kind = .renewalNotice }
        else if s.contains("confirmed")                    { kind = .confirmed }
        else { return nil }

        let text = AppleReceiptParser.plainText(html)
        var record = AppStoreRecord(kind: kind, date: date)
        record.account = recipients
        record.groupID = capture(#"familyId=(\d+)"#, in: html)
        // Confirmations show the app's real icon; renewal notices often only
        // a placeholder, which the ledger ignores.
        record.iconURL = capture(#"<img[^>]*src="(https://is\d+-ssl\.mzstatic\.com/[^"]+)""#, in: html)

        if kind == .confirmed {
            readConfirmation(text, into: &record)
        } else {
            readLockup(html, into: &record)
        }
        guard record.app != nil || record.plan != nil else { return nil }

        switch kind {
        case .renewalNotice:
            record.renewal = findDate(after: #"(?i)starting\s+(?:from|on)?\s*"#, in: text)
                ?? findDate(after: #"(?i)renews?\s+on\s+"#, in: text)
        case .expiring:
            record.renewal = expiryDate(in: text, received: date)
        default:
            break
        }
        return record
    }

    /// Renewal and Expiring notices: the lines of the header block.
    private static func readLockup(_ html: String, into r: inout AppStoreRecord) {
        var scope = html
        if let start = html.range(of: "artwork-cell") {
            let rest = html[start.upperBound...]
            let end = rest.range(of: "Dear ")?.lowerBound ?? rest.endIndex
            scope = String(rest[..<end])
        }
        let lines = captures(#"(?s)<span[^>]*>(.*?)</span>"#, in: scope)
            .map(AppleReceiptParser.plainText)
            .filter { !$0.isEmpty }

        let planIndex = lines.firstIndex { AppleReceiptParser.period(in: periodPart(of: $0)) != nil
                                           && $0.contains("(") }
        if let i = planIndex {
            r.plan = AppleReceiptParser.stripPeriods(lines[i])
            r.cycle = AppleReceiptParser.period(in: periodPart(of: lines[i]))
            if i > 0 { r.app = usable(lines[0]) }
        } else if let first = lines.first {
            r.app = usable(first)
        }
        if let price = lines.lazy.compactMap(pricePerPeriod).first {
            r.amount = price.amount
            r.currency = price.currency
            r.cycle = r.cycle ?? price.cycle
        }
    }

    /// Confirmed notices: labelled fields, read from the flattened text.
    ///
    ///     Grammarly Premium                          ← heading (group)
    ///     App            Grammarly: AI Keyboard & Voice
    ///     Subscription   Quarterly Plan
    ///     Content Provider  Superhuman Platform Inc
    ///     Renewal Price  ₹1,999.00/3 months, starting 21 September 2026
    ///
    /// Apple's own services (Creator Studio, Fitness+) have no App field, so
    /// the heading names them.
    private static func readConfirmation(_ text: String, into r: inout AppStoreRecord) {
        let labels = #"(?:Subscription|Content Provider|Date Accepted|Trial|Renewal Price|Price|Dear)\b"#
        var body = text
        for marker in ["following offer", "confirms your subscription purchase"] {
            if let range = text.range(of: marker) { body = String(text[range.upperBound...]); break }
        }
        r.app = capture(#"(?s)\bApp\s+(.+?)\s+"# + labels, in: body).flatMap(usable)
        r.plan = capture(#"(?s)\bSubscription\s+(.+?)\s+(?:Content Provider|Date Accepted|Trial|Renewal Price|Price)\b"#,
                         in: body)
            .map(AppleReceiptParser.stripPeriods)
        if r.app == nil {
            // "Subscription Confirmed Apple Creator Studio Dear Joseph"
            r.app = capture(#"(?is)Subscription Confirmed\s+(.+?)\s+(?:Dear|App\b)"#, in: text)
                .map(AppleReceiptParser.stripPeriods)
                .flatMap(usable)
        }
        // Read from the text after the label, not up to the next comma:
        // "₹1,999.00/3 months" has one inside the number.
        if let price = capture(#"(?is)(?:Renewal Price|Price)\s+(.{1,60})"#, in: body)
            .flatMap(pricePerPeriod) {
            r.amount = price.amount
            r.currency = price.currency
            r.cycle = price.cycle
        }
        let accepted = findDate(after: #"(?i)Date Accepted\s+"#, in: body)
        // The first charge: after the trial when there is one, else a cycle
        // after the day it was accepted.
        r.renewal = findDate(after: #"(?i)starting\s+"#,
                         in: capture(#"(?is)(?:Renewal Price|Price)\s+(.+?)(?:Your|$)"#, in: body) ?? "")
            ?? accepted.map { (r.cycle ?? .monthly).advance($0) }
    }

    // MARK: Helpers

    /// "Pro Monthly Plan (1 month)" → "1 month"
    private static func periodPart(of line: String) -> String {
        capture(#"\(([^)]*)\)\s*$"#, in: line) ?? ""
    }

    /// "₹400.00/month", "₹ 1,999.00/3 months", "₹ 235.00 every month…"
    static func pricePerPeriod(_ s: String) -> (amount: Double, currency: String, cycle: BillingCycle?)? {
        let pattern = #"(₹|Rs\.?|INR|US\$|\$|USD|€|EUR|£|GBP|OMR|AED|SAR)\s*([0-9][0-9,]*(?:\.[0-9]{1,3})?)\s*(?:/|every|per)?\s*([0-9]*\s*(?:month|year|week|day)s?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let cr = Range(m.range(at: 1), in: s), let nr = Range(m.range(at: 2), in: s),
              let value = Double(s[nr].replacingOccurrences(of: ",", with: "")), value > 0
        else { return nil }
        let code: String
        switch s[cr].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) {
        case "₹", "rs", "inr":  code = "INR"
        case "$", "us$", "usd": code = "USD"
        case "€", "eur":        code = "EUR"
        case "£", "gbp":        code = "GBP"
        default:                code = s[cr].uppercased()
        }
        let period = Range(m.range(at: 3), in: s).map { String(s[$0]) } ?? ""
        return (value, code, AppleReceiptParser.period(in: period))
    }

    /// "expires on 22 October." — Apple leaves the year out; it's the first
    /// such date on or after the email.
    private static func expiryDate(in text: String, received: Date) -> Date? {
        if let full = findDate(after: #"(?i)expires?\s+on\s+"#, in: text) { return full }
        guard let dayMonth = capture(#"(?i)expires?\s+on\s+(\d{1,2}\s+[A-Za-z]+)"#, in: text) else { return nil }
        let cal = Calendar.current
        let year = cal.component(.year, from: received)
        for y in [year, year + 1] {
            if let d = AppleReceiptParser.parseDate("\(dayMonth) \(y)"),
               d >= cal.date(byAdding: .day, value: -1, to: received) ?? received {
                return d
            }
        }
        return nil
    }

    private static func findDate(after prefix: String, in text: String) -> Date? {
        let pattern = prefix + #"(\d{1,2}\s+[A-Za-z]{3,9},?\s+\d{4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})"#
        return capture(pattern, in: text).flatMap(AppleReceiptParser.parseDate)
    }

    private static func usable(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = t.lowercased()
        let notNames: Set<String> = ["", "monthly", "yearly", "annual", "weekly", "quarterly",
                                     "subscription", "subscriptions", "app store", "apple services"]
        return notNames.contains(l) ? nil : t
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        captures(pattern, in: text).first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func captures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.range(at: 1).location == NSNotFound ? nil : ns.substring(with: $0.range(at: 1))
        }
    }
}

// MARK: - Ledger

/// Works out the App Store subscriptions — which exist, which are still live —
/// from every record together.
///
/// **Identity.** One subscription reaches the inbox under several names: the
/// receipt says "Wispr Flow: AI Voice Keyboard", an older receipt only "Pro
/// Monthly Plan", the renewal notice adds its group "Flow Pro". Records are
/// joined when, for the same account, they share the app, the subscription
/// group id, the app icon, a distinctive plan name, or a plan name together
/// with its price.
///
/// **Status.** Only a receipt is a payment. A plan is live while its latest
/// renewal date — from a receipt, or from a later confirmation or reminder —
/// hasn't passed by more than a week without a new receipt. An Expiring
/// notice, a refund or the service's own cancellation email, newer than the
/// latest payment, ends it.
enum AppStoreLedger {

    /// All App Store subscriptions, live and ended, from the records.
    static func subscriptions(from records: [AppStoreRecord], me given: String) -> [Subscription] {
        let me = resolveMe(given, records: records)
        let tracked = records.filter { $0.kind != .vendorCancel }
        let cancels = records.filter { $0.kind == .vendorCancel }

        // Union-find over records that share a key.
        var parent = Array(tracked.indices)
        func find(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        var owner: [String: Int] = [:]
        for (i, r) in tracked.enumerated() {
            for key in linkKeys(r, me: me) {
                if let j = owner[key] {
                    let ri = find(i), rj = find(j)
                    parent[ri] = rj
                } else {
                    owner[key] = i
                }
            }
        }
        var clusters: [Int: [AppStoreRecord]] = [:]
        for i in tracked.indices { clusters[find(i), default: []].append(tracked[i]) }

        return clusters.values.compactMap { group in
            resolve(group.sorted { a, b in a.date < b.date }, me: me, cancels: cancels)
        }
    }

    // MARK: Identity

    /// Whose plan a record is about: nil for the user's own, else the family
    /// member's address.
    static func member(of r: AppStoreRecord, me: String) -> String? {
        guard let raw = r.account?.lowercased() else { return nil }
        let emails = emailPattern.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            .compactMap { Range($0.range, in: raw).map { String(raw[$0]) } }
        return emails.first { $0 != me }
    }

    /// The user's address. Without a connected Gmail address, it's the
    /// account on most receipts — the organiser's.
    private static func resolveMe(_ me: String, records: [AppStoreRecord]) -> String {
        let given = me.lowercased()
        if !given.isEmpty { return given }
        var counts: [String: Int] = [:]
        for r in records where r.kind == .receipt {
            if let a = r.account?.lowercased() { counts[a, default: 0] += 1 }
        }
        return counts.max { $0.value < $1.value }?.key ?? ""
    }

    private static let emailPattern = try! NSRegularExpression(
        pattern: #"[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}"#)

    /// "Wispr Flow: AI Voice Keyboard" → "Wispr Flow"; "Grok - AI Assistant"
    /// → "Grok"; "ZEE5 Movies, Web Series, Shows" → "ZEE5 Movies". The App
    /// Store subtitle after the separator changes from release to release
    /// ("LinkedIn: Job Search & Network" became "LinkedIn: Community &
    /// Network"); the name before it doesn't.
    static func displayName(_ app: String) -> String {
        var s = app.trimmingCharacters(in: .whitespaces)
        for sep in [":", " - ", " – ", " — ", " | ", ","] {
            if let r = s.range(of: sep) {
                let head = s[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                if !head.isEmpty { s = head }
            }
        }
        return s
    }

    static func key(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// A plan name that could only belong to one app — "Whatsapp Plus",
    /// "SuperGrok" — as opposed to "Pro Monthly Plan", "Family", "Monthly".
    static func isDistinctive(_ plan: String) -> Bool {
        let p = plan.lowercased().trimmingCharacters(in: .whitespaces)
        guard p.count >= 3 else { return false }
        let generic = #"^(?:(?:the|pro|premium|plus|basic|standard|vip|family|individual|student|duo|personal|two-person|single|lite|ultra|max)\s*)*(?:(?:monthly|yearly|annual|annually|weekly|quarterly|\d+\s*(?:month|year|week)s?)\s*)*(?:plan|subscription|membership|pack)?$"#
        return p.range(of: generic, options: .regularExpression) == nil
    }

    /// An icon that identifies a third-party app. Apple's own artwork
    /// ("Features/…", "Placeholder") is shared and identifies nothing.
    static func iconKey(_ url: String?) -> String? {
        guard let url = url, url.contains("/Purple"), !url.contains("Placeholder") else { return nil }
        return AppleReceiptParser.iconKey(from: url)
    }

    private static func linkKeys(_ r: AppStoreRecord, me: String) -> [String] {
        let m = member(of: r, me: me) ?? ""
        var keys: [String] = []
        if let app = r.app { keys.append("\(m)|app|\(key(displayName(app)))") }
        if let g = r.groupID { keys.append("\(m)|group|\(g)") }
        if let icon = iconKey(r.iconURL) { keys.append("\(m)|icon|\(icon)") }
        if let plan = r.plan {
            if isDistinctive(plan) { keys.append("\(m)|plan|\(key(plan))") }
            if let amount = r.amount {
                keys.append("\(m)|price|\(key(plan))|\(Int((amount * 100).rounded()))")
            }
        }
        return keys
    }

    // MARK: Status

    private static func resolve(_ recs: [AppStoreRecord], me: String,
                                cancels: [AppStoreRecord]) -> Subscription? {
        guard let first = recs.first else { return nil }
        let whose = member(of: first, me: me)
        let receipts = recs.filter { $0.kind == .receipt }
        let lastReceipt = receipts.last

        let name: String = {
            if let app = recs.last(where: { $0.app != nil })?.app { return displayName(app) }
            if let plan = recs.last(where: { $0.plan.map(isDistinctive) == true })?.plan { return plan }
            return "App Store plan"
        }()
        let plan = (lastReceipt ?? recs.last(where: { $0.plan != nil }))?.plan
        let priced = lastReceipt ?? recs.last(where: { $0.amount != nil })
        guard let amount = priced?.amount, amount > 0 else { return nil }
        let cycle = priced?.cycle ?? recs.last(where: { $0.cycle != nil })?.cycle ?? .monthly

        // The newest sign it was paid for or taken out.
        let lastPositive = recs.last { $0.kind == .receipt || $0.kind == .confirmed }

        // When it next renews: the latest receipt's date, unless a later
        // confirmation or reminder names a newer one.
        let since = lastReceipt?.date ?? .distantPast
        let dates = ([lastReceipt?.renewal] + recs.filter {
            ($0.kind == .confirmed || $0.kind == .renewalNotice) && $0.date >= since
        }.map(\.renewal)).compactMap { $0 }
        guard let expected = dates.max()
                ?? lastReceipt.map({ cycle.advance($0.date) })
                ?? recs.last.map({ cycle.advance($0.date) }) else { return nil }

        // What ended it, if anything did after the latest payment.
        let stop = recs.last { ($0.kind == .expiring || $0.kind == .refund)
                               && $0.date >= (lastPositive?.date ?? .distantPast) }
        // Only the user's own plans: a family member's cancellation email
        // goes to them, not here.
        var vendorStop: AppStoreRecord? = nil
        if whose == nil {
            vendorStop = cancels.last(where: { c in
                c.date > (lastReceipt?.date ?? .distantPast) && sameService(c.app, name)
            })
        }

        var sub = Subscription(name: name, amount: amount,
                               currencyCode: priced?.currency ?? "", cycle: cycle,
                               startedOn: first.date,
                               lastChargedOn: cycle.advance(expected, by: -1),
                               isDetected: true)
        sub.viaApple = true
        sub.planName = plan
        sub.iconURL = receipts.last(where: { $0.iconURL != nil })?.iconURL
            ?? recs.last(where: { iconKey($0.iconURL) != nil })?.iconURL
        sub.accountEmail = whose
        sub.chargeCount = max(receipts.count, 1)
        sub.sourceKey = "appstore|\(whose ?? "")|\(key(name))"
        sub.startedOn = min(first.date, sub.lastChargedOn)

        if let ended = [stop, vendorStop].compactMap({ $0 }).max(by: { $0.date < $1.date }) {
            sub.cancelledOn = ended.date
            sub.endsOn = ended.kind == .refund ? ended.date : (ended.renewal ?? expected)
        }

        // Every app name it has gone by, and its subscription group, so
        // removing it holds whichever name the next email uses. Plan names
        // are left out on purpose: removing an old duplicate row called
        // "Family" must not hide the real Apple One.
        let m = whose ?? ""
        var keys: Set<String> = [sub.sourceKey ?? ""]
        for r in recs {
            if let app = r.app {
                keys.insert("appstore|\(m)|\(app.lowercased())")
                keys.insert("appstore|\(m)|\(displayName(app).lowercased())")
            }
            if let g = r.groupID { keys.insert("appstore|\(m)|group:\(g)") }
        }
        sub.matchKeys = keys.sorted()
        return sub
    }

    /// The service's own cancellation email names it loosely — "Wispr" for
    /// "Wispr Flow".
    private static func sameService(_ vendor: String?, _ name: String) -> Bool {
        guard let vendor = vendor else { return false }
        let a = key(displayName(vendor)), b = key(name)
        guard min(a.count, b.count) >= 4 else { return a == b && !a.isEmpty }
        if a.hasPrefix(b) || b.hasPrefix(a) { return true }
        if let x = SubscriptionBrand.match(vendor), let y = SubscriptionBrand.match(name) {
            return x.name == y.name
        }
        return false
    }
}
