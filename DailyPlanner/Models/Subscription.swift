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
        // Only the subscription products: a bare "microsoft" also matches
        // one-off Store and Xbox game purchases.
        .init(name: "Microsoft 365",  keywords: ["microsoft 365", "office 365", "msft *microsoft",
                                                 "xbox game pass", "game pass"],
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

        .init(name: "WhatsApp",       keywords: ["whatsapp"],
              color: Color(red: 0.15, green: 0.83, blue: 0.40), symbol: "message.fill"),

        // Telecom (often billed monthly in the Gulf)
        .init(name: "Ooredoo",        keywords: ["ooredoo"],
              color: Color(red: 0.89, green: 0.10, blue: 0.20), symbol: "antenna.radiowaves.left.and.right"),
        .init(name: "Omantel",        keywords: ["omantel"],
              color: Color(red: 0.95, green: 0.55, blue: 0.09), symbol: "antenna.radiowaves.left.and.right"),
    ]

    /// Finds the brand a bank description belongs to, longest keyword first so
    /// "amazon prime" wins over a bare "amazon".
    /// Matching runs for every row on every redraw, and short keywords need a
    /// regular expression, so results are remembered.
    private static var matchCache: [String: SubscriptionBrand?] = [:]

    static func match(_ text: String) -> SubscriptionBrand? {
        if let cached = matchCache[text] { return cached }
        let result = uncachedMatch(text)
        matchCache[text] = result
        return result
    }

    private static func uncachedMatch(_ text: String) -> SubscriptionBrand? {
        let lower = text.lowercased()
        var best: (brand: SubscriptionBrand, length: Int)? = nil
        for brand in catalogue {
            for keyword in brand.keywords where contains(keyword, in: lower) {
                if best == nil || keyword.count > best!.length {
                    best = (brand, keyword.count)
                }
            }
        }
        return best?.brand
    }

    /// The name a plan is stored and matched under.
    ///
    /// A recognised brand uses its catalogue name ("OPENAI *CHATGPT" ->
    /// "OpenAI"), with one exception: Apple. Apple's own App Store services —
    /// iCloud+, Apple One, Apple Fitness+ — all contain an Apple keyword, and
    /// collapsing them to "Apple" merged separate plans into one row. They keep
    /// their own names; only the bank's bare "APPLE.COM/BILL" line is "Apple".
    static func canonicalName(_ name: String) -> String {
        if let brand = match(name), brand.name != "Apple" { return brand.name }
        return name
    }

    /// Short keywords must stand as whole words: "canva" is inside "CANVAS ART
    /// SUPPLIES" and "osn" inside plenty of shop names. Longer brand names are
    /// distinctive enough as substrings, which matters because bank
    /// descriptors often glue words together ("DISNEYPLUS", "NETFLIX.COM").
    private static func contains(_ keyword: String, in lower: String) -> Bool {
        guard keyword.count < 6 else { return lower.contains(keyword) }
        let pattern = #"(?<![a-z0-9])"# + NSRegularExpression.escapedPattern(for: keyword)
                    + #"(?![a-z0-9])"#
        return lower.range(of: pattern, options: .regularExpression) != nil
    }

    /// A stand-in for anything not in the catalogue, coloured from its name so
    /// the same service always gets the same tile colour.
    static func generic(named name: String) -> SubscriptionBrand {
        let palette: [Color] = [
            Color(red: 0.36, green: 0.42, blue: 0.95), Color(red: 0.11, green: 0.65, blue: 0.52),
            Color(red: 0.93, green: 0.42, blue: 0.20), Color(red: 0.62, green: 0.31, blue: 0.86),
            Color(red: 0.14, green: 0.58, blue: 0.80), Color(red: 0.85, green: 0.26, blue: 0.45),
        ]
        // Not `hashValue`: Swift seeds it afresh on every launch, so tiles
        // changed colour each time the app opened.
        let idx = name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % palette.count
        return SubscriptionBrand(name: name, keywords: [], color: palette[idx],
                                 symbol: "creditcard.fill")
    }
}

// MARK: - Category

/// Where subscription money goes, for the breakdown at the top of the page.
enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
    case entertainment = "Entertainment"
    case ai            = "AI & Productivity"
    case photoVideo    = "Photo & Video"
    case cloud         = "Cloud & Storage"
    case social        = "Social & Messaging"
    case telecom       = "Telecom"
    case education     = "Education & Kids"
    case finance       = "Finance & News"
    case health        = "Health & Lifestyle"
    case developer     = "Developer"
    case other         = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .entertainment: return "play.tv.fill"
        case .ai:            return "sparkles"
        case .photoVideo:    return "camera.fill"
        case .cloud:         return "icloud.fill"
        case .social:        return "bubble.left.and.bubble.right.fill"
        case .telecom:       return "antenna.radiowaves.left.and.right"
        case .education:     return "graduationcap.fill"
        case .finance:       return "chart.line.uptrend.xyaxis"
        case .health:        return "heart.fill"
        case .developer:     return "hammer.fill"
        case .other:         return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .entertainment: return Color(red: 0.90, green: 0.22, blue: 0.27)
        case .ai:            return Color(red: 0.42, green: 0.36, blue: 0.92)
        case .photoVideo:    return Color(red: 0.95, green: 0.45, blue: 0.20)
        case .cloud:         return Color(red: 0.16, green: 0.55, blue: 0.95)
        case .social:        return Color(red: 0.15, green: 0.70, blue: 0.45)
        case .telecom:       return Color(red: 0.93, green: 0.60, blue: 0.10)
        case .education:     return Color(red: 0.95, green: 0.35, blue: 0.60)
        case .finance:       return Color(red: 0.10, green: 0.60, blue: 0.55)
        case .health:        return Color(red: 0.85, green: 0.30, blue: 0.45)
        case .developer:     return Color(red: 0.35, green: 0.40, blue: 0.50)
        case .other:         return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }

    /// A best guess from the app and plan names. The user can override it.
    static func infer(name: String, plan: String?) -> SubscriptionCategory {
        let t = (name + " " + (plan ?? "")).lowercased()
        let rules: [(SubscriptionCategory, [String])] = [
            (.developer,     ["developer program", "apple developer", "github"]),
            (.telecom,       ["ooredoo", "omantel", "vodafone", "airtel", "jio", "telecom"]),
            (.cloud,         ["icloud", "google one", "dropbox", "storage", "apple one", "2 tb"]),
            (.ai,            ["openai", "chatgpt", "anthropic", "claude", "grok", "gemini",
                              "perplexity", "grammarly", "notion", "wispr", "keyboard",
                              "higgsfield", "copilot", "microsoft 365", "ai assistant"]),
            (.photoVideo,    ["photo", "video", "inshot", "lightroom", "canva", "b612",
                              "creator studio", "adobe", "capcut", "camera"]),
            (.entertainment, ["netflix", "disney", "prime video", "amazon prime", "youtube",
                              "spotify", "zee5", "liv", "hotstar", "shahid", "osn", "anghami",
                              "premium hd", "music", "tv", "movies"]),
            (.social,        ["whatsapp", "linkedin", "x premium", "telegram", "instagram",
                              "snapchat", "facebook"]),
            (.education,     ["coloring", "typing", "kids", "learn", "duolingo", "school"]),
            (.finance,       ["moneycontrol", "equitymaster", "stock", "market", "news",
                              "finance", "invest"]),
            (.health,        ["daylio", "mood", "journal", "fitness", "health", "sleep",
                              "meditation", "calm", "headspace"]),
        ]
        for (category, words) in rules where words.contains(where: { t.contains($0) }) {
            return category
        }
        // "X" alone is too short to search for as a word.
        if name.trimmingCharacters(in: .whitespaces).lowercased() == "x" { return .social }
        return .other
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
    /// Set when the user cancels the plan. The record is kept — what you used
    /// to pay for is worth remembering — but it stops counting towards the
    /// next payment and the totals.
    var cancelledOn: Date? = nil
    /// Billed through the App Store. These are listed apart, and their
    /// presence hides the generic "Apple" row that bank alerts produce
    /// ("APPLE.COM/BILL"), which would otherwise count the same money twice.
    var viaApple: Bool = false
    /// The key this plan was first detected under. Kept when the user renames
    /// it, so the next receipt still finds it instead of starting a duplicate.
    var sourceKey: String? = nil
    /// The amount in the currency it was actually charged in, when that
    /// differs from the user's — an Indian App Store account bills in rupees.
    var originalAmount: Double? = nil
    /// The plan within the app — "SuperGrok", "Pro Monthly Plan". Shown under
    /// the app's name, the way Apple's own subscription list does.
    var planName: String? = nil
    /// The app's real icon. App Store receipts carry it on Apple's own CDN.
    var iconURL: String? = nil
    /// The Apple Account the plan belongs to, or for a renewal notice the To
    /// line. With Family Sharing the organiser receives every member's mail,
    /// so this tells the user's own plans from a family member's.
    var accountEmail: String? = nil
    /// Chosen by the user; otherwise worked out from the name.
    var category: SubscriptionCategory? = nil
    /// Set while a receipt is being read: it named only the plan, so the app
    /// still has to be looked up from what other receipts taught us. Not stored.
    var nameIsPlanOnly: Bool = false

    /// The category shown and grouped by.
    var effectiveCategory: SubscriptionCategory {
        category ?? SubscriptionCategory.infer(name: name, plan: planName)
    }
    /// True when it came from imported spending rather than being typed in.
    var isDetected: Bool = false
    /// How many charges the detector matched. One means the cycle is a guess.
    var chargeCount: Int = 1

    /// A stable key for a detected subscription, so hiding one sticks.
    var detectionKey: String { sourceKey ?? name.lowercased() }

    /// Still running, so it still has a next payment.
    var isActive: Bool { cancelledOn == nil && lapsedOn == nil }

    /// When an App Store plan ran out without being cancelled by email.
    ///
    /// Apple emails a receipt on every renewal, so a renewal date that passed a
    /// week ago with no new receipt means the plan expired — the way the
    /// user's LinkedIn, Canva and Lightroom plans did. Without this the
    /// schedule rolled forward forever and expired plans sat under Active.
    ///
    /// Only App Store plans the user hasn't edited: bank-detected plans can
    /// have gaps simply because a month was never synced, and an edited plan
    /// is the user's call.
    var lapsedOn: Date? {
        guard viaApple, isDetected, cancelledOn == nil else { return nil }
        let expected = cycle.advance(lastChargedOn)
        let grace = Calendar.current.date(byAdding: .day, value: 7, to: expected) ?? expected
        return grace < Calendar.current.startOfDay(for: Date()) ? expected : nil
    }

    /// Cancelled or expired, whichever applies — for sorting the Inactive list.
    var endedOn: Date? { cancelledOn ?? lapsedOn }

    var brand: SubscriptionBrand {
        if let known = SubscriptionBrand.match(name) { return known }
        if viaApple {
            // An App Store plan the receipt didn't name — Apple's tax invoice
            // shows the app only as an icon — still reads as App Store.
            return SubscriptionBrand(name: name, keywords: ["app store"],
                                     color: Color(red: 0.04, green: 0.52, blue: 1.0),
                                     symbol: "app.badge.fill")
        }
        return SubscriptionBrand.generic(named: name)
    }

    /// Next payment date, rolled forward past any charge we never saw imported.
    ///
    /// Every step is measured from the last payment rather than from the step
    /// before it. Adding a month to the 31st lands on the 28th, so advancing
    /// one month at a time would walk a plan billed on the 31st back to the
    /// 28th permanently; anchoring on the original date restores the 31st in
    /// every month long enough to have one.
    var nextDue: Date {
        let today = Calendar.current.startOfDay(for: Date())
        var periods = 1
        var next = cycle.advance(lastChargedOn, by: periods)
        while next < today && periods < 400 {
            periods += 1
            next = cycle.advance(lastChargedOn, by: periods)
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
        case planName, iconURL, accountEmail, category
        case id, name, amount, currencyCode, cycle, startedOn, lastChargedOn,
             cancelledOn, viaApple, sourceKey, originalAmount, isDetected, chargeCount
    }

    init(id: UUID = UUID(), name: String, amount: Double, currencyCode: String = "",
         cycle: BillingCycle = .monthly, startedOn: Date, lastChargedOn: Date,
         cancelledOn: Date? = nil, isDetected: Bool = false, chargeCount: Int = 1) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.cycle = cycle
        self.startedOn = startedOn
        self.lastChargedOn = lastChargedOn
        self.cancelledOn = cancelledOn
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
        cancelledOn   = try c.decodeIfPresent(Date.self,         forKey: .cancelledOn)
        viaApple      = try c.decodeIfPresent(Bool.self,         forKey: .viaApple) ?? false
        sourceKey     = try c.decodeIfPresent(String.self,       forKey: .sourceKey)
        originalAmount = try c.decodeIfPresent(Double.self,      forKey: .originalAmount)
        planName      = try c.decodeIfPresent(String.self,       forKey: .planName)
        iconURL       = try c.decodeIfPresent(String.self,       forKey: .iconURL)
        accountEmail  = try c.decodeIfPresent(String.self,       forKey: .accountEmail)
        category      = try c.decodeIfPresent(SubscriptionCategory.self, forKey: .category)
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

    /// Only two things make a charge a subscription:
    ///
    ///   1. the email it came from talked about renewing, a billing period or
    ///      a plan, or
    ///   2. the merchant is a service we recognise.
    ///
    /// Recurrence on its own is explicitly NOT enough. The first version of
    /// this accepted any merchant that charged twice for a similar amount, and
    /// the page filled with restaurants, pharmacies, petrol stations and a
    /// furniture shop — all of which genuinely do charge you about the same
    /// amount about once a month. The real subscriptions were lost among them.
    static func detect(from entries: [String: DailyEntry]) -> [Subscription] {
        struct Charge { let date: Date; let amount: Double }

        var byService: [String: [Charge]] = [:]
        var displayName: [String: String] = [:]

        for (_, entry) in entries {
            for expense in entry.expenses where !expense.isIncome && !expense.isDeposit {
                guard expense.amount > 0 else { continue }
                let text = expense.description
                guard !text.isEmpty else { continue }

                let brand = SubscriptionBrand.match(text)

                // The gate. Everything else is an ordinary purchase.
                guard brand != nil || expense.isSubscription else { continue }

                let key = brand?.name.lowercased() ?? normalise(text)
                guard key.count >= 3 else { continue }

                displayName[key] = brand?.name ?? titleCased(text)
                byService[key, default: []].append(
                    Charge(date: entry.date, amount: expense.amount))
            }
        }

        return byService.compactMap { key, charges in
            let sorted = charges.sorted { $0.date < $1.date }
            // Price, schedule and start date all come from the plan's own
            // charges, so a one-off charge from the same company (API credits,
            // a top-up) can't distort any of them.
            let plan = planCharges(sorted.map { (date: $0.date, amount: $0.amount) })
            guard let last = plan.last, let first = plan.first else { return nil }
            var sub = Subscription(
                name: displayName[key] ?? key.capitalized,
                amount: last.amount,
                cycle: inferCycle(from: plan.map(\.date)),
                startedOn: first.date,
                lastChargedOn: last.date,
                isDetected: true,
                chargeCount: plan.count)
            sub.sourceKey = key
            return sub
        }
    }

    /// The charges that belong to the plan itself, oldest first.
    ///
    /// Charges within 3% of each other are treated as one plan: a USD plan
    /// billed to an OMR card lands a few baisa apart each month as the rate
    /// moves ($20 shows as 7.69, then 7.70). Matching to the exact baisa, as
    /// before, meant no two charges ever agreed, so the newest won — and for
    /// OpenAI that was a one-off OMR 40.357 charge, not the $20 plan.
    ///
    /// A group that recurs beats any one-off. Among recurring groups, the one
    /// charged most recently wins, so a genuine price rise shows once it has
    /// repeated.
    private static func planCharges(_ charges: [(date: Date, amount: Double)])
        -> [(date: Date, amount: Double)] {
        var groups: [[(date: Date, amount: Double)]] = []
        for c in charges {
            if let i = groups.firstIndex(where: { abs($0[0].amount - c.amount) <= $0[0].amount * 0.03 }) {
                groups[i].append(c)
            } else {
                groups.append([c])
            }
        }
        let recurring = groups.filter { $0.count >= 2 }
        let pool = recurring.isEmpty ? groups : recurring
        let best = pool.max { a, b in
            let la = a.last!.date, lb = b.last!.date
            // Same day: prefer the smaller charge, the likelier base plan.
            return la != lb ? la < lb : a.last!.amount > b.last!.amount
        }
        return best ?? charges
    }

    /// Infers the billing period from the gaps between the plan's charges.
    ///
    /// A plan billed on the same day each month leaves gaps of whole months,
    /// and when a month was never synced the gap simply doubles or triples.
    /// The median gap read those as "Quarterly" — Ooredoo, paid around the 10th
    /// of every month, came out quarterly. So the shortest real gap decides,
    /// and quarterly is only believed when at least two gaps are each about
    /// three months. Gaps under 20 days (an add-on, or a charge and its
    /// reversal) are ignored, weekly needs three evenly spaced charges, and
    /// anything unclear is monthly.
    private static func inferCycle(from dates: [Date]) -> BillingCycle {
        guard dates.count >= 2 else { return .monthly }
        let cal = Calendar.current
        var gaps: [Int] = []
        for i in 1..<dates.count {
            if let d = cal.dateComponents([.day], from: dates[i - 1], to: dates[i]).day {
                gaps.append(d)
            }
        }

        if dates.count >= 3, gaps.allSatisfy({ (6...8).contains($0) }) { return .weekly }

        let periodGaps = gaps.filter { $0 >= 20 }
        guard let shortest = periodGaps.min() else { return .monthly }

        if shortest >= 330 { return .yearly }
        if periodGaps.count >= 2, periodGaps.allSatisfy({ (80...100).contains($0) }) {
            return .quarterly
        }
        return .monthly
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
