import Foundation

// MARK: - Card charges from bank alerts

/// One card charge read from a bank alert, kept for subscription detection.
///
/// Subscriptions billed to a card — Higgsfield, OpenAI, Anthropic,
/// ElevenLabs — leave no receipt the app can rely on, but every one of them
/// leaves a bank alert: "Your credit card … used for USD 49.000 at HIGGSFIELD
/// INC. on 12/10/2026". Those used to count only once imported as expenses,
/// so a renewal the user hadn't reviewed yet was simply missed. The full
/// Gmail scan now keeps the charges that look like subscriptions as records,
/// whether or not they were ever imported.
/// A service saying a new billing period began, without an amount —
/// Audible's monthly "Your new credit is here!". Lines up a payment
/// processor's charge (Amazon, Google) with the service it paid for.
struct RenewalNoticeRecord: Codable, Equatable {
    var date: Date
    var service: String

    var signature: String { "\(service.lowercased())|\(Int(date.timeIntervalSince1970 / 3600))" }
}

struct CardChargeRecord: Codable, Equatable {
    var date: Date
    /// As the bank prints it, e.g. "HIGGSFIELD INC."
    var merchant: String
    var amount: Double
    /// ISO code, e.g. "USD".
    var currency: String

    var signature: String {
        let minute = Int(date.timeIntervalSince1970 / 60)
        return "\(merchant.lowercased())|\(String(format: "%.3f", amount))|\(currency)|\(minute)"
    }
}

enum CardChargeParser {

    /// Reads one card charge out of a bank alert, or nil when the alert is
    /// anything else — a declined or reversed charge, a payment received,
    /// an upcoming debit, an OTP.
    ///
    /// Banks word these differently; all of these are read:
    ///   • "used for USD 49.000 at HIGGSFIELD INC. on 12/10/2026" (Bank Muscat card)
    ///   • "Description : 029855-Disney Plus London GB Amount : OMR 5.146
    ///      Date/Time : 14 SEP 26 00:13" (Bank Muscat debit card)
    ///   • "Your NETFLIX bill, set up through E-mandate (Auto payment), has been
    ///      successfully paid … Amount: INR 499.00 Date: 11/10/2026" (HDFC)
    ///   • "Rs.199.00 is debited from your HDFC Bank Debit Card ending 2769 at
    ///      AMAZON INDIA CYBS SI on 25 Sep, 2026" (HDFC card, standing instruction)
    static func parse(body: String, receivedOn received: Date) -> CardChargeRecord? {
        let text = body.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let lower = text.lowercased()
        let notACharge = ["declined", "reversed", "reversal", "refund", "credited", "has been paid",
                          "payment of", "otp", "one time password", "insufficient", "upcoming",
                          "will be debited", "is due on"]
        guard !notACharge.contains(where: { lower.contains($0) }) else { return nil }

        if let charge = mandate(in: text, received: received) { return charge }
        if let charge = described(in: text, received: received) { return charge }
        if let charge = atMerchant(in: text, received: received) { return charge }
        return bankFee(in: text, received: received)
    }

    private static let currency = #"(USD|US\$|\$|EUR|€|GBP|£|AED|SAR|QAR|KWD|BHD|INR|Rs\.?|OMR|SGD|AUD|CAD)"#
    private static let number = #"([0-9][0-9,]*(?:\.[0-9]{1,3})?)"#
    private static let dateToken = #"(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}[ -][A-Za-z]{3,9},?[ -]\d{2,4})"#

    /// Auto-debits the bank set up for a merchant: always a subscription.
    private static func mandate(in text: String, received: Date) -> CardChargeRecord? {
        guard let merchant = capture(#"(?i)your\s+(.+?)\s+bill,?\s+set up through\s+e-?mandate"#, in: text),
              let money = amount(after: #"(?i)amount\s*:?\s*"#, in: text) else { return nil }
        let date = capture(#"(?i)\bdate\s*:?\s*"# + dateToken, in: text).flatMap(parseDate) ?? received
        return CardChargeRecord(date: date, merchant: merchant + " (e-mandate)",
                                amount: money.0, currency: money.1)
    }

    /// "Description : 029855-Disney Plus London GB Amount : OMR 5.146 Date/Time : 14 SEP 26"
    private static func described(in text: String, received: Date) -> CardChargeRecord? {
        guard var merchant = capture(#"(?i)description\s*:\s*(.+?)\s+amount\s*:"#, in: text),
              let money = amount(after: #"(?i)amount\s*:\s*"#, in: text) else { return nil }
        // Terminal numbers and city suffixes the bank adds: "029855-Disney Plus London GB".
        merchant = merchant.replacingOccurrences(of: #"^\d+\s*-\s*"#, with: "", options: .regularExpression)
        let date = capture(#"(?i)date(?:\s*/\s*time)?\s*:\s*"# + dateToken, in: text).flatMap(parseDate) ?? received
        guard merchant.count >= 2 else { return nil }
        return CardChargeRecord(date: date, merchant: merchant, amount: money.0, currency: money.1)
    }

    /// "<currency> <amount> … at|towards <merchant> on <date>"
    private static func atMerchant(in text: String, received: Date) -> CardChargeRecord? {
        let pattern: String = #"(?i)"# + currency + #"\s?"# + number
            + #"[^.]{0,90}?\s(?:at|towards|to|with)\s+(.+?)\s+(?:on|dated)\s+"# + dateToken
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges == 5,
              let cr = Range(m.range(at: 1), in: text), let nr = Range(m.range(at: 2), in: text),
              let mr = Range(m.range(at: 3), in: text), let dr = Range(m.range(at: 4), in: text),
              let value = Double(text[nr].replacingOccurrences(of: ",", with: "")), value > 0
        else { return nil }

        var merchant = String(text[mr]).trimmingCharacters(in: .whitespacesAndNewlines)
        // UPI: "VPA primevideorentals@apl (Prime Video Rentals)" — the name is in brackets.
        if let named = capture(#"\(([^)]{2,40})\)"#, in: merchant) { merchant = named }
        guard merchant.count >= 2 else { return nil }
        return CardChargeRecord(date: parseDate(String(text[dr])) ?? received,
                                merchant: merchant, amount: value,
                                currency: iso(String(text[cr])))
    }

    private static func amount(after label: String, in text: String) -> (Double, String)? {
        let pattern: String = label + currency + #"\s?"# + number
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let cr = Range(m.range(at: 1), in: text), let nr = Range(m.range(at: 2), in: text),
              let value = Double(text[nr].replacingOccurrences(of: ",", with: "")), value > 0
        else { return nil }
        return (value, iso(String(text[cr])))
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A bank's own recurring fee — "Annual fee of OMR 25.000 has been
    /// charged to your card", "membership fee … debited". These alerts name
    /// no merchant, so the fee itself becomes the name.
    private static func bankFee(in text: String, received: Date) -> CardChargeRecord? {
        let currency = #"(USD|EUR|GBP|AED|SAR|QAR|KWD|BHD|INR|Rs\.?|OMR)"#
        let number = #"([0-9][0-9,]*(?:\.[0-9]{1,3})?)"#
        let fee = #"((?:annual|yearly|membership|renewal|joining|subscription)\s+fees?)"#
        let feeFirst: String = #"(?i)"# + fee + #"[^.]{0,60}?"# + currency + #"\s?"# + number
        let amountFirst: String = #"(?i)"# + currency + #"\s?"# + number + #"[^.]{0,60}?"# + fee
        for (pattern, feeGroup, curGroup, numGroup) in [(feeFirst, 1, 2, 3), (amountFirst, 3, 1, 2)] {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let fr = Range(m.range(at: feeGroup), in: text),
                  let cr = Range(m.range(at: curGroup), in: text),
                  let nr = Range(m.range(at: numGroup), in: text),
                  let amount = Double(text[nr].replacingOccurrences(of: ",", with: "")), amount > 0
            else { continue }
            let label = String(text[fr]).lowercased()
            return CardChargeRecord(date: received, merchant: "Card " + label,
                                    amount: amount, currency: iso(String(text[cr])))
        }
        return nil
    }

    /// Whether a charge is worth keeping as subscription evidence: a known
    /// service, a descriptor that says so ("…SUBSCR", "CLAUDE.AI"), an AI
    /// tool, or a charge in a currency other than the user's own — services
    /// sold online bill in dollars, the corner shop doesn't. Shopping sites
    /// that also bill in dollars are left out.
    static func isCandidate(_ charge: CardChargeRecord, localCurrency: String) -> Bool {
        let m = charge.merchant.lowercased()
        // A rental or a one-off order is never a plan, whatever the brand.
        if ["rental", "rent ", "order"].contains(where: { m.contains($0) }) { return false }
        // An auto-debit the bank set up is a subscription even at Amazon —
        // that is how Audible bills ("AMAZON INDIA CYBS SI").
        if looksLikeSubscription(charge.merchant) { return true }
        if SubscriptionBrand.match(charge.merchant) != nil { return true }
        if shopping.contains(where: { m.contains($0) }) { return false }
        return CurrencyConverter.needsConversion(detected: charge.currency, local: localCurrency)
    }

    /// Bank descriptors that name a subscription or an AI service outright.
    static func looksLikeSubscription(_ merchant: String) -> Bool {
        let m = " " + merchant.lowercased() + " "
        let words = ["subscr", "subscription", "membership", "recurring", " sub ",
                     "annual fee", "yearly fee", "renewal fee",
                     "e-mandate", "mandate", "autopay", "auto pay", "auto-pay",
                     "standing instruction", " si ", "cybs si",
                     ".ai ", " ai ", "gpt", "openai", "llm"]
        return words.contains { m.contains($0) }
    }

    /// Merchants that bill in dollars without being subscriptions.
    static let shopping = ["amazon", "amzn mktp", "temu", "aliexpress", "shein", "noon", "ebay",
                           "booking.com", "airbnb", "agoda", "expedia", "uber", "careem",
                           "talabat", "steam", "playstation", "xbox", "etsy", "walmart",
                           "ikea", "iherb", "apple.com/bill"]

    private static func iso(_ token: String) -> String {
        switch token.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) {
        case "$", "US$", "USD": return "USD"
        case "€", "EUR":        return "EUR"
        case "£", "GBP":        return "GBP"
        case "RS", "INR":       return "INR"
        default:                return token.uppercased()
        }
    }

    private static func parseDate(_ raw: String) -> Date? {
        // "14 SEP 26" → "14 Sep 26"; "25 Sep, 2026" → "25 Sep 2026"
        let cleaned = raw.capitalized.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "Sept", with: "Sep")
        for fmt in ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "dd/MM/yy", "d-M-yyyy", "dd-MM-yy",
                    "d MMM yyyy", "d MMMM yyyy", "d MMM yy", "d-MMM-yyyy", "d-MMM-yy"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            // A two-digit year read by a four-digit format comes out as 0026.
            if let d = f.date(from: cleaned), Calendar.current.component(.year, from: d) >= 2000 {
                return d
            }
        }
        return nil
    }
}
