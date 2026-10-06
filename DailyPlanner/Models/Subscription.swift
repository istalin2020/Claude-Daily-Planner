import SwiftUI

// MARK: - Billing cycle

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly    = "Weekly"
    case monthly   = "Monthly"
    case quarterly = "Quarterly"
    case yearly    = "Yearly"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .weekly:    return 7
        case .monthly:   return 30
        case .quarterly: return 91
        case .yearly:    return 365
        }
    }

    /// What one year of this plan costs, for the yearly projection.
    var timesPerYear: Double {
        switch self {
        case .weekly:    return 52
        case .monthly:   return 12
        case .quarterly: return 4
        case .yearly:    return 1
        }
    }

    /// Advances a date by exactly one cycle, using real calendar months so a
    /// subscription billed on the 31st doesn't drift backwards each month.
    func advance(_ date: Date, by periods: Int = 1) -> Date {
        let cal = Calendar.current
        switch self {
        case .weekly:    return cal.date(byAdding: .day,   value: 7 * periods, to: date) ?? date
        case .monthly:   return cal.date(byAdding: .month, value: 1 * periods, to: date) ?? date
        case .quarterly: return cal.date(byAdding: .month, value: 3 * periods, to: date) ?? date
        case .yearly:    return cal.date(byAdding: .year,  value: 1 * periods, to: date) ?? date
        }
    }

    /// Picks the closest cycle to an observed gap between two charges.
    static func nearest(toDays gap: Int) -> BillingCycle {
        let candidates: [BillingCycle] = [.weekly, .monthly, .quarterly, .yearly]
        return candidates.min(by: { abs($0.days - gap) < abs($1.days - gap) }) ?? .monthly
    }
}

// MARK: - Brand

/// A recognised service, so a bank line like "NETFLIX.COM 866-579-7172" is
/// shown as "Netflix" in its own colour.
///
/// Brand marks are deliberately NOT bundled: shipping other companies' logos
/// without a licence is a trademark problem and a plausible App Store
/// rejection. A coloured monogram in the brand's own palette is our own
/// artwork, reads just as fast in a list, and costs nothing legally.
struct SubscriptionBrand: Equatable {
    let name: String
    let keywords: [String]
    let color: Color
    let symbol: String

    /// One or two letters for the tile.
    var monogram: String {
        let words = name.split(separator: " ")
        if words.count >= 2, let a = words[0].first, let b = words[1].first {
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    static let catalogue: [SubscriptionBrand] = [
        // Streaming
        .init(name: "Netflix",        keywords: ["netflix"],
              color: Color(red: 0.90, green: 0.09, blue: 0.16), symbol: "play.rectangle.fill"),
        .init(name: "Amazon Prime",   keywords: ["amazon prime", "prime video", "amznprime"],
              color: Color(red: 0.00, green: 0.66, blue: 0.84), symbol: "shippingbox.fill"),
        .init(name: "Disney+",        keywords: ["disney"],
              color: Color(red: 0.05, green: 0.20, blue: 0.58), symbol: "sparkles.tv.fill"),
        .init(name: "Spotify",        keywords: ["spotify"],
              color: Color(red: 0.11, green: 0.73, blue: 0.33), symbol: "music.note"),
        .init(name: "YouTube",        keywords: ["youtube", "google youtube"],
              color: Color(red: 1.00, green: 0.00, blue: 0.00), symbol: "play.rectangle.fill"),
        .init(name: "Shahid",         keywords: ["shahid"],
              color: Color(red: 0.14, green: 0.60, blue: 0.47), symbol: "play.tv.fill"),
        .init(name: "OSN",            keywords: ["osn"],
              color: Color(red: 0.85, green: 0.16, blue: 0.40), symbol: "play.tv.fill"),
        .init(name: "Anghami",        keywords: ["anghami"],
              color: Color(red: 0.49, green: 0.25, blue: 0.85), symbol: "music.note"),

        // AI & developer
        .init(name: "OpenAI",         keywords: ["openai", "chatgpt"],
              color: Color(red: 0.04, green: 0.65, blue: 0.53), symbol: "brain.head.profile"),
        .init(name: "Anthropic",      keywords: ["anthropic", "claude.ai"],
              color: Color(red: 0.80, green: 0.45, blue: 0.27), symbol: "brain.head.profile"),
        .init(name: "GitHub",         keywords: ["github"],
              color: Color(red: 0.14, green: 0.16, blue: 0.18), symbol: "chevron.left.forwardslash.chevron.right"),
        .init(name: "Higgsfield",     keywords: ["higgsfield"],
              color: Color(red: 0.36, green: 0.31, blue: 0.86), symbol: "wand.and.stars"),

        // Productivity & cloud
        .init(name: "Apple",          keywords: ["apple.com/bill", "itunes", "apple services",
                                                 "icloud", "apple one"],
              color: Color(red: 0.35, green: 0.35, blue: 0.38), symbol: "applelogo"),
        .init(name: "Google One",     keywords: ["google one", "google storage", "google *one"],
              color: Color(red: 0.26, green: 0.52, blue: 0.96), symbol: "externaldrive.fill"),
        .init(name: "Microsoft",      keywords: ["microsoft", "office 365", "microsoft 365"],
              color: Color(red: 0.00, green: 0.47, blue: 0.83), symbol: "square.grid.2x2.fill"),
        .init(name: "Adobe",          keywords: ["adobe"],
              color: Color(red: 0.92, green: 0.15, blue: 0.16), symbol: "paintbrush.pointed.fill"),
        .init(name: "Dropbox",        keywords: ["dropbox"],
              color: Color(red: 0.00, green: 0.38, blue: 0.93), symbol: "shippingbox.fill"),
        .init(name: "Notion",         keywords: ["notion"],
              color: Color(red: 0.20, green: 0.20, blue: 0.20), symbol: "doc.text.fill"),
        .init(name: "Canva",          keywords: ["canva"],
              color: Color(red: 0.00, green: 0.78, blue: 0.80), symbol: "paintpalette.fill"),
        .init(name: "LinkedIn",       keywords: ["linkedin"],
              color: Color(red: 0.04, green: 0.40, blue: 0.64), symbol: "person.2.fill"),
        .init(name: "Zoom",           keywords: ["zoom.us", "zoom video"],
              color: Color(red: 0.18, green: 0.47, blue: 1.00), symbol: "video.fill"),

        // Telecom (often billed monthly in the Gulf)
        .init(name: "Ooredoo",        keywords: ["ooredoo"],
              color: Color(red: 0.89, green: 0.10, blue: 0.20), symbol: "antenna.radiowaves.left.and.right"),
        .init(name: "Omantel",        keywords: ["omantel"],
              color: Color(red: 0.95, green: 0.55, blue: 0.09), symbol: "antenna.radiowaves.left.and.right"),
    ]

    /// Finds the brand a bank description belongs to, longest keyword first so
    /// "amazon prime" wins over a bare "amazon".
    static func match(_ text: String) -> SubscriptionBrand? {
        let lower = text.lowercased()
        var best: (brand: SubscriptionBrand, length: Int)? = nil
        for brand in catalogue {
            for keyword in brand.keywords where lower.contains(keyword) {
                if best == nil || keyword.count > best!.length {
                    best = (brand, keyword.count)
                }
            }
        }
        return best?.brand
    }

    /// A stand-in for anything not in the catalogue, coloured from its name so
    /// the same service always gets the same tile colour.
    static func generic(named name: String) -> SubscriptionBrand {
        let palette: [Color] = [
            Color(red: 0.36, green: 0.42, blue: 0.95), Color(red: 0.11, green: 0.65, blue: 0.52),
            Color(red: 0.93, green: 0.42, blue: 0.20), Color(red: 0.62, green: 0.31, blue: 0.86),
            Color(red: 0.14, green: 0.58, blue: 0.80), Color(red: 0.85, green: 0.26, blue: 0.45),
        ]
        let idx = abs(name.lowercased().hashValue) % palette.count
        return SubscriptionBrand(name: name, keywords: [], color: palette[idx],
                                 symbol: "creditcard.fill")
    }
}

// MARK: - Subscription

struct Subscription: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
    var currencyCode: String = ""
    var cycle: BillingCycle = .monthly
    /// The earliest charge seen — shown as "Member since".
    var startedOn: Date
    /// The most recent charge seen; the next due date is derived from it.
    var lastChargedOn: Date
    /// True when it came from imported spending rather than being typed in.
    var isDetected: Bool = false
    /// How many charges the detector matched. One means the cycle is a guess.
    var chargeCount: Int = 1

    /// A stable key for a detected subscription, so hiding one sticks.
    var detectionKey: String { name.lowercased() }

    var brand: SubscriptionBrand {
        SubscriptionBrand.match(name) ?? SubscriptionBrand.generic(named: name)
    }

    /// Next payment date, rolled forward past any charge we never saw imported.
    var nextDue: Date {
        let today = Calendar.current.startOfDay(for: Date())
        var next = cycle.advance(lastChargedOn)
        var guard_ = 0
        while next < today && guard_ < 400 {
            next = cycle.advance(next)
            guard_ += 1
        }
        return next
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: nextDue)).day ?? 0
    }

    /// What this plan costs over a year.
    var yearlyCost: Double { amount * cycle.timesPerYear }

    /// Averaged to a month, so plans on different cycles can be compared.
    var monthlyCost: Double { yearlyCost / 12 }

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, currencyCode, cycle, startedOn, lastChargedOn,
             isDetected, chargeCount
    }

    init(id: UUID = UUID(), name: String, amount: Double, currencyCode: String = "",
         cycle: BillingCycle = .monthly, startedOn: Date, lastChargedOn: Date,
         isDetected: Bool = false, chargeCount: Int = 1) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.cycle = cycle
        self.startedOn = startedOn
        self.lastChargedOn = lastChargedOn
        self.isDetected = isDetected
        self.chargeCount = chargeCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self,         forKey: .id) ?? UUID()
        name          = try c.decode(String.self,                forKey: .name)
        amount        = try c.decodeIfPresent(Double.self,       forKey: .amount) ?? 0
        currencyCode  = try c.decodeIfPresent(String.self,       forKey: .currencyCode) ?? ""
        cycle         = try c.decodeIfPresent(BillingCycle.self, forKey: .cycle) ?? .monthly
        startedOn     = try c.decodeIfPresent(Date.self,         forKey: .startedOn) ?? Date()
        lastChargedOn = try c.decodeIfPresent(Date.self,         forKey: .lastChargedOn) ?? Date()
        isDetected    = try c.decodeIfPresent(Bool.self,         forKey: .isDetected) ?? false
        chargeCount   = try c.decodeIfPresent(Int.self,          forKey: .chargeCount) ?? 1
    }
}

// MARK: - Detection

/// Finds recurring payments in spending the app has already imported.
///
/// No new permission and no new service: the bank alerts synced from Gmail
/// already name the merchant and the amount, and a subscription is simply a
/// merchant that keeps coming back. Anything the detector misses can be added
/// by hand — which is also the answer for App Store subscriptions, since Apple
/// provides no way for one app to read another's.
enum SubscriptionDetector {

    /// A charge has to repeat, or be a recognised service, before it counts.
    /// A single unrecognised shop is just a purchase.
    static func detect(from entries: [String: DailyEntry]) -> [Subscription] {
        struct Charge { let date: Date; let amount: Double; let currency: String }

        var byService: [String: [Charge]] = [:]
        var displayName: [String: String] = [:]

        for (_, entry) in entries {
            for expense in entry.expenses where !expense.isIncome && !expense.isDeposit {
                guard expense.amount > 0 else { continue }
                let text = expense.description
                guard !text.isEmpty else { continue }

                let brand = SubscriptionBrand.match(text)
                // Unrecognised merchants are keyed on a normalised name so the
                // same shop groups together across months.
                let key = brand?.name.lowercased() ?? normalise(text)
                guard !key.isEmpty, key.count >= 3 else { continue }

                displayName[key] = brand?.name ?? titleCased(text)
                byService[key, default: []].append(
                    Charge(date: entry.date, amount: expense.amount, currency: ""))
            }
        }

        var result: [Subscription] = []

        for (key, charges) in byService {
            let sorted = charges.sorted { $0.date < $1.date }
            let isKnownBrand = SubscriptionBrand.catalogue.contains { $0.name.lowercased() == key }

            // One-off from an unknown merchant: not a subscription.
            guard sorted.count >= 2 || isKnownBrand else { continue }

            // Repeated charges must be for a similar amount — a supermarket
            // visited twice is not a subscription.
            if sorted.count >= 2 && !isKnownBrand {
                let amounts = sorted.map(\.amount)
                let lo = amounts.min() ?? 0, hi = amounts.max() ?? 0
                guard lo > 0, hi / lo <= 1.25 else { continue }
            }

            let cycle = inferCycle(from: sorted.map(\.date), fallbackAmountCount: sorted.count)
            let last = sorted.last!

            result.append(Subscription(
                name: displayName[key] ?? key.capitalized,
                amount: last.amount,
                cycle: cycle,
                startedOn: sorted.first!.date,
                lastChargedOn: last.date,
                isDetected: true,
                chargeCount: sorted.count))
        }

        return result
    }

    /// Median gap between charges decides the cycle; a single charge defaults
    /// to monthly, which is what most subscriptions are.
    private static func inferCycle(from dates: [Date], fallbackAmountCount: Int) -> BillingCycle {
        guard dates.count >= 2 else { return .monthly }
        let cal = Calendar.current
        var gaps: [Int] = []
        for i in 1..<dates.count {
            if let d = cal.dateComponents([.day], from: dates[i - 1], to: dates[i]).day, d > 0 {
                gaps.append(d)
            }
        }
        guard !gaps.isEmpty else { return .monthly }
        let sortedGaps = gaps.sorted()
        let median = sortedGaps[sortedGaps.count / 2]
        return BillingCycle.nearest(toDays: median)
    }

    /// Strips the noise banks add so the same merchant groups together.
    private static func normalise(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: #"[0-9]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[^a-z ]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func titleCased(_ raw: String) -> String {
        let cleaned = normalise(raw)
        return cleaned.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
