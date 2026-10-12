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
    /// an OTP.
    static func parse(body: String, receivedOn received: Date) -> CardChargeRecord? {
        let text = body.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let lower = text.lowercased()
        let notACharge = ["declined", "reversed", "reversal", "refund", "credited", "has been paid",
                          "payment of", "otp", "one time password", "insufficient"]
        guard !notACharge.contains(where: { lower.contains($0) }) else { return nil }

        let currency = #"(USD|US\$|\$|EUR|€|GBP|£|AED|SAR|QAR|KWD|BHD|INR|Rs\.?|OMR|SGD|AUD|CAD)"#
        let number = #"([0-9][0-9,]*(?:\.[0-9]{1,3})?)"#
        // "used for USD 49.000 at HIGGSFIELD INC. on 12/10/2026 00:18:23"
        // "was used for USD 20.000 at CLAUDE.AI SUBSCRIPTION on 12/04/2026"
        // "spent USD 20.00 at OPENAI on 12-05-2026"
        let pattern = #"(?i)"# + currency + #"\s?"# + number
            + #"\s+(?:at|to|towards|with)\s+(.+?)\s+(?:on|dated)\s+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return bankFee(in: text, received: received) }
        guard m.numberOfRanges == 5,
              let cr = Range(m.range(at: 1), in: text), let nr = Range(m.range(at: 2), in: text),
              let mr = Range(m.range(at: 3), in: text), let dr = Range(m.range(at: 4), in: text),
              let amount = Double(text[nr].replacingOccurrences(of: ",", with: "")), amount > 0
        else { return nil }

        let merchant = String(text[mr]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard merchant.count >= 2 else { return nil }
        return CardChargeRecord(date: parseDate(String(text[dr])) ?? received,
                                merchant: merchant, amount: amount,
                                currency: iso(String(text[cr])))
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
        if shopping.contains(where: { m.contains($0) }) { return false }
        if SubscriptionBrand.match(charge.merchant) != nil { return true }
        if looksLikeSubscription(charge.merchant) { return true }
        return CurrencyConverter.needsConversion(detected: charge.currency, local: localCurrency)
    }

    /// Bank descriptors that name a subscription or an AI service outright.
    static func looksLikeSubscription(_ merchant: String) -> Bool {
        let m = " " + merchant.lowercased() + " "
        let words = ["subscr", "subscription", "membership", "recurring", " sub ",
                     "annual fee", "yearly fee", "renewal fee",
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
        for fmt in ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "dd/MM/yy", "d-M-yyyy"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
}
