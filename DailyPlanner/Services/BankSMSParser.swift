import Foundation

struct ParsedTransaction: Codable {
    let amount: Double
    let isCredit: Bool
    let merchant: String
    let category: ExpenseCategory
    let bankName: String
    let accountLast4: String
    let balance: Double?
    let rawText: String
    let currencyDetected: String
    let confidenceType: ConfidenceLevel
    let confidenceCategory: ConfidenceLevel
    /// Masked card number exactly as it appears in the message,
    /// e.g. "4228**** ****2787". Empty when the message has none.
    let cardNumber: String
    /// Raw "Date/Time" text from the message, e.g. "13 JUL 26 23:11".
    /// Empty when the message has no explicit date/time line.
    let txnDateTime: String

    enum ConfidenceLevel: String, Codable {
        case high
        case low
    }
}

struct BankSMSParser {

    private static let currencyPatterns: [(codes: [String], regex: String)] = [
        (["INR", "Rs", "₹"], #"(?:Rs\.?|INR|₹)"#),
        (["OMR"], #"(?:OMR)"#),
        (["AED"], #"(?:AED)"#),
        (["SAR"], #"(?:SAR)"#),
        (["USD", "$"], #"(?:USD|\$)"#),
        (["EUR", "€"], #"(?:EUR|€)"#),
        (["GBP", "£"], #"(?:GBP|£)"#),
        (["KWD"], #"(?:KWD)"#),
        (["BHD"], #"(?:BHD)"#),
        (["QAR"], #"(?:QAR)"#),
        (["SGD"], #"(?:SGD)"#),
        (["MYR", "RM"], #"(?:MYR|RM)"#),
        (["PKR"], #"(?:PKR)"#),
        (["BDT"], #"(?:BDT)"#),
        (["LKR"], #"(?:LKR)"#),
        (["NPR"], #"(?:NPR)"#),
    ]

    static func parse(_ text: String) -> ParsedTransaction? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let (amount, currency) = extractAmount(from: trimmed) else { return nil }
        let (isCredit, typeConfidence) = detectCreditWithConfidence(in: trimmed)
        let merchant = extractMerchant(from: trimmed)
        let (category, catConfidence) = categorizeWithConfidence(merchant: merchant, text: trimmed)
        let bankName = detectBank(in: trimmed)
        let accountLast4 = extractAccount(from: trimmed)
        let balance = extractBalance(from: trimmed)

        return ParsedTransaction(
            amount: amount,
            isCredit: isCredit,
            merchant: merchant,
            category: category,
            bankName: bankName,
            accountLast4: accountLast4,
            balance: balance,
            rawText: trimmed,
            currencyDetected: currency,
            confidenceType: typeConfidence,
            confidenceCategory: catConfidence,
            cardNumber: extractCardNumber(from: trimmed),
            txnDateTime: extractDateTimeText(from: trimmed)
        )
    }

    static func looksLikeBankSMS(_ text: String) -> Bool {
        let lower = text.lowercased()

        // Reject bank mail that isn't an actual transaction — OTPs, security
        // alerts, statements and marketing all mention money and accounts but
        // represent nothing that should land in the expense tracker.
        let notATransaction = [
            "one time password", "one-time password", "otp is", "otp for",
            "your otp", "verification code", "security code", "do not share",
            "never share", "login attempt", "password reset", "password change",
            "e-statement", "estatement", "statement is ready",
            "statement is now available", "your statement for",
            "minimum amount due", "total amount due", "payment due date",
            "credit limit increase", "pre-approved", "pre approved",
            "special offer", "exclusive offer", "limited time offer",
            "cashback offer", "apply now", "terms and conditions apply",
            "kyc", "cheque book", "chequebook", "interest certificate"
        ]
        if notATransaction.contains(where: { lower.contains($0) }) { return false }

        // Reject promotional mail. Loose keywords are not enough on their own:
        // a sweepstakes email says "NO PURCHASE NECESSARY" (an action word) and
        // "gift card" (an account word), which is exactly how marketing was
        // slipping through as a transaction.
        if isMarketing(lower) { return false }

        // A genuine bank alert has STRUCTURE that marketing never has:
        //   1. a masked account or card reference, AND
        //   2. either the amount sitting near a transaction verb (one-line SMS
        //      style), or a block of labelled transaction fields (the layout
        //      Bank Muscat and most Gulf banks use in email alerts).
        //
        // Requiring (2) by proximity alone was wrong: in a labelled email the
        // verb is in the header line and the amount is several lines below, so
        // whether it passed depended on how long the merchant name happened to
        // be. Real transactions were silently dropped for having a wordy
        // merchant.
        guard hasMaskedAccountReference(text) else { return false }
        return hasAmountNearTransactionVerb(lower) || hasLabelledTransactionFields(lower)
    }

    /// Newsletter / promo / sweepstakes markers.
    static func isMarketing(_ lower: String) -> Bool {
        let markers = [
            "no purchase necessary", "void where prohibited", "sweepstakes",
            "gift card", "you could win", "chance to win", "enter to win",
            "enter now", "view in browser", "view this email in",
            "manage preferences", "manage your preferences", "email preferences",
            "unsubscribe from", "newsletter", "weekly briefing", "market outlook",
            "webinar", "free trial", "upgrade now", "subscribe to",
            "sale ends", "shop now", "book now", "claim your", "you're invited",
            "invitation", "referral", "refer a friend", "survey", "feedback form"
        ]
        return markers.contains(where: { lower.contains($0) })
    }

    /// True when the text contains a masked account or card number, e.g.
    /// "4228**** ****2787", "Account number : xxxx0028", "A/c XX1234",
    /// "Credit Card ending 4455".
    private static func hasMaskedAccountReference(_ text: String) -> Bool {
        let patterns = [
            #"[0-9]{3,6}[X\*x]{2,}[\s\-]?[X\*x]*[0-9]{2,4}"#,
            #"(?i)(?:a/c|acct|account|card)\s*(?:no\.?|number|ending(?:\s+(?:with|in))?)?\s*[:#]?\s*[X\*x]{2,}\s*[0-9]{2,4}"#,
            #"(?i)(?:ending|ending\s+(?:with|in)|last\s*4\s*digits?)\s*[:#]?\s*[0-9]{4}"#,
            #"[X\*x]{3,}[0-9]{3,4}"#
        ]
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    /// Shared currency alternation, used by every amount-matching pattern.
    private static let currencyAlternation =
        #"(?:rs\.?|inr|₹|omr|aed|sar|usd|\$|eur|€|gbp|£|kwd|bhd|qar|sgd|myr|pkr|bdt|lkr|npr)"#

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { return false }
        let ns = text as NSString
        return regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
    }

    /// True when the text is laid out as a bank's labelled field block, e.g.
    ///
    ///     Account number : xxxx0028
    ///     Description : 459403-GULF OCEAN INTERNATIONAOM
    ///     Amount : OMR 4.62
    ///     Date/Time : 22 SEP 26 14:48
    ///
    /// An "Amount:" line carrying a real figure, plus at least one other
    /// transaction field. Marketing email does not have this shape, so the
    /// structure alone is strong enough evidence without needing the amount to
    /// sit near a verb.
    private static func hasLabelledTransactionFields(_ lower: String) -> Bool {
        let amountLine = #"amount\s*[:\-]\s*"# + currencyAlternation + #"?\s*[\d,]+(?:\.\d{1,3})?"#
        guard matches(amountLine, lower) else { return false }

        let supporting = [
            #"account\s*(?:number|no\.?|#)\s*[:\-]"#,
            #"card\s*(?:number|no\.?|#)\s*[:\-]"#,
            #"date\s*/?\s*time\s*[:\-]"#,
            #"description\s*[:\-]"#,
            #"transaction\s+(?:country|date|type|reference)\s*[:\-]"#,
            #"merchant\s*[:\-]"#,
        ]
        return supporting.contains { matches($0, lower) }
    }

    /// True when a currency amount appears near a verb describing money moving.
    /// Adjacency stops a long marketing email from qualifying just because a
    /// price and a stray verb both exist somewhere in it.
    ///
    /// The window is generous (250 chars) because a labelled bank email can put
    /// several field lines between the verb and the amount; the masked-account
    /// requirement in `looksLikeBankSMS` is what actually keeps marketing out.
    private static func hasAmountNearTransactionVerb(_ lower: String) -> Bool {
        let verbs = ["debited", "credited", "withdrawn", "spent", "utilised",
                     "utilized", "charged", "transferred", "deposited",
                     "refunded", "reversed", "used", "purchase", "payment",
                     "debit", "credit"]

        let pattern = currencyAlternation + #"\s*[\d,]+(?:\.\d{1,3})?"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let ns = lower as NSString
        let matches = regex.matches(in: lower, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            let start = max(0, match.range.location - 250)
            let end   = min(ns.length, match.range.location + match.range.length + 250)
            let window = ns.substring(with: NSRange(location: start, length: end - start))
            if verbs.contains(where: { window.contains($0) }) { return true }
        }
        return false
    }

    // MARK: - Amount

    /// Finds the transacted amount.
    ///
    /// Order matters. A message often carries more than one figure — the amount
    /// spent AND the balance or remaining limit — so picking by currency-list
    /// order was wrong: "used for USD 5.000 ... Available limit: OMR 0.562"
    /// recorded the leftover limit as the expense, because OMR is checked
    /// before USD. Now a labelled "Amount:" line wins outright, balance and
    /// limit figures are excluded, and what's left is scored by nearness to a
    /// transaction verb.
    private static func extractAmount(from text: String) -> (Double, String)? {
        // 1. An explicit "Amount : OMR 4.62" line is authoritative.
        let labelled = #"(?i)amount\s*[:\-]\s*("# + currencyAlternation + #")?\s*([0-9,]+(?:\.[0-9]{1,3})?)"#
        if let regex = try? NSRegularExpression(pattern: labelled),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let numRange = Range(match.range(at: 2), in: text) {
            let digits = String(text[numRange]).replacingOccurrences(of: ",", with: "")
            if let val = Double(digits), val > 0 {
                var code = ""
                if let curRange = Range(match.range(at: 1), in: text) {
                    code = normalizedCurrencyCode(String(text[curRange]))
                }
                return (val, code)
            }
        }

        // 2. Otherwise score every currency amount in the message.
        let ns = text as NSString
        let lower = text.lowercased() as NSString
        let anyAmount = "(" + currencyAlternation + #")\s*([0-9,]+(?:\.[0-9]{1,3})?)"#

        // Figures introduced by these describe what's LEFT, not what moved.
        let notTheAmount = ["available limit", "avl limit", "available balance",
                            "avl bal", "avlbal", "balance", "bal:", "bal :",
                            "limit:", "limit :", "remaining"]
        let verbs = ["debited", "credited", "withdrawn", "spent", "utilised",
                     "utilized", "charged", "transferred", "deposited",
                     "refunded", "reversed", "used", "purchase", "payment"]

        if let regex = try? NSRegularExpression(pattern: anyAmount, options: .caseInsensitive) {
            var best: (value: Double, code: String, distance: Int)? = nil

            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard let numRange = Range(match.range(at: 2), in: text),
                      let curRange = Range(match.range(at: 1), in: text) else { continue }
                let digits = String(text[numRange]).replacingOccurrences(of: ",", with: "")
                guard let val = Double(digits), val > 0 else { continue }

                // Skip balances and remaining limits.
                let lookBackStart = max(0, match.range.location - 30)
                let lookBack = lower.substring(with: NSRange(location: lookBackStart,
                                                            length: match.range.location - lookBackStart))
                if notTheAmount.contains(where: { lookBack.contains($0) }) { continue }

                // Prefer the amount closest to a verb describing money moving.
                var distance = Int.max
                for verb in verbs {
                    var searchStart = 0
                    while searchStart < lower.length {
                        let found = lower.range(of: verb,
                                                range: NSRange(location: searchStart,
                                                               length: lower.length - searchStart))
                        if found.location == NSNotFound { break }
                        let gap = abs(match.range.location - found.location)
                        distance = min(distance, gap)
                        searchStart = found.location + 1
                    }
                }

                let code = normalizedCurrencyCode(String(text[curRange]))
                if best == nil || distance < best!.distance {
                    best = (val, code, distance)
                }
            }

            if let best = best { return (best.value, best.code) }
        }

        // 3. Last resort: a bare "1,234.00 is debited" with no currency symbol.
        let genericPattern = #"([0-9,]+\.[0-9]{1,3})\s+is\s+(?:debited|credited)"#
        if let regex = try? NSRegularExpression(pattern: genericPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let r = Range(match.range(at: 1), in: text) {
                let digits = String(text[r]).replacingOccurrences(of: ",", with: "")
                if let val = Double(digits), val > 0 {
                    return (val, "")
                }
            }
        }

        return nil
    }

    /// Maps a matched currency token ("Rs.", "₹", "usd") to its canonical code.
    private static func normalizedCurrencyCode(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !token.isEmpty else { return "" }
        for entry in currencyPatterns {
            for code in entry.codes where token == code.lowercased()
                || token == code.lowercased() + "." {
                return entry.codes[0]
            }
        }
        return raw.uppercased()
    }

    // MARK: - Credit / Debit

    private static func detectCreditWithConfidence(in text: String) -> (Bool, ParsedTransaction.ConfidenceLevel) {
        // "credit card" / "debit card" name the INSTRUMENT, not the money
        // direction — a purchase made WITH a credit card is an expense.
        // Neutralize those phrases so they never influence detection.
        let lower = text.lowercased()
            .replacingOccurrences(of: #"credit\s+card"#, with: "card", options: .regularExpression)
            .replacingOccurrences(of: #"debit\s+card"#,  with: "card", options: .regularExpression)

        // A reversal or refund is money coming BACK, whatever verb the original
        // transaction used. "utilised as follows has been reversed" names the
        // spend first, so the nearest-word scoring below would call it a debit
        // and the refund would be logged as another expense.
        let reversalMarkers = ["has been reversed", "been reversed", "reversal of",
                               "is reversed", "has been refunded", "been refunded",
                               "refund of", "refunded to"]
        if reversalMarkers.contains(where: { lower.contains($0) }) {
            return (true, .high)
        }

        let creditWords = ["credited", "credit", "received", "deposited", "refund",
                           "cash back", "cashback", "reversed", "added", "incoming"]
        let debitWords = ["debited", "debit", "spent", "withdrawn", "sent",
                          "paid", "purchase", "transferred", "payment", "outgoing",
                          "utilised", "utilized", "has been used", "charged"]

        var creditPos = Int.max
        var debitPos = Int.max

        for word in creditWords {
            if let range = lower.range(of: word) {
                let pos = lower.distance(from: lower.startIndex, to: range.lowerBound)
                creditPos = min(creditPos, pos)
            }
        }
        for word in debitWords {
            if let range = lower.range(of: word) {
                let pos = lower.distance(from: lower.startIndex, to: range.lowerBound)
                debitPos = min(debitPos, pos)
            }
        }

        if creditPos == Int.max && debitPos == Int.max {
            return (false, .low)
        }

        return (creditPos < debitPos, .high)
    }

    // MARK: - Merchant

    private static func extractMerchant(from text: String) -> String {
        let patterns: [(String, Int)] = [
            // Bank emails often carry an explicit "Description : <merchant>" line —
            // always the most reliable source, so try it first. Stop at the next
            // "Label :" so single-line (HTML-flattened) bodies don't leak through.
            (#"(?i)description\s*[:\-]\s*(.+?)\s+(?:amount|date\s*/?\s*time|transaction\s+country|currency|balance|avl|available|card|account)\s*[:\-]"#, 1),
            (#"(?i)description\s*[:\-]\s*([^\n\r]{2,40})"#, 1),
            (#"(?:POS|pos)[:\s]+(.+?)(?:\.|,|$|\n)"#, 1),
            (#"(?:UPI)[:\s/-]+(.+?)(?:\.|,|$|\n|Ref)"#, 1),
            (#"(?:to|at|for|towards)\s+([A-Z][A-Za-z0-9 &'.@-]{2,30})"#, 1),
            (#"(?:from|by)\s+([A-Z][A-Za-z0-9 &'.@-]{2,30})"#, 1),
            (#"Info[:\s]+(.+?)(?:\.|,|$|\n)"#, 1),
        ]

        for (pattern, group) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
               let range = Range(match.range(at: group), in: text) {
                var merchant = String(text[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".-,;:"))

                let stopWords = ["avl", "bal", "available", "balance", "ref", "upi",
                                 "neft", "imps", "a/c", "new available", "on "]
                for stop in stopWords {
                    if let idx = merchant.lowercased().range(of: stop) {
                        merchant = String(merchant[merchant.startIndex..<idx.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                merchant = cleanMerchantName(merchant)
                if merchant.count >= 2 && merchant.count <= 40 {
                    return merchant
                }
            }
        }
        return ""
    }

    /// Turns a raw bank description into a readable shop / reason name.
    ///
    /// Banks prefix merchants with terminal or reference numbers and often
    /// truncate the tail, e.g. "899795-SUHOOL AL TAMAM LLC Ghu" →
    /// "SUHOOL AL TAMAM LLC". This strips the numeric IDs, embedded reference
    /// codes and trailing fragments so only the meaningful name remains.
    static func cleanMerchantName(_ raw: String) -> String {
        var s = raw

        // Order matters: strip reference codes with their labels BEFORE the
        // bare-number rules, otherwise the number goes and the label ("Ref",
        // "TXN:") is left stranded.

        // 1. Labelled reference codes: "Ref 998877", "TXN:AB12345", "UTR 12345"
        s = s.replacingOccurrences(
            of: #"(?i)\b(?:ref(?:erence)?|txn|trn|rrn|utr|auth|approval|invoice|inv|id)\b\s*(?:no\.?|number)?\s*[:#\-]?\s*[A-Z0-9]{3,}"#,
            with: "", options: .regularExpression)

        // 2. Leading currency + amount: "OMR 3.300 at LULU" → "LULU"
        s = s.replacingOccurrences(
            of: #"(?i)^\s*(?:[A-Z]{3}|rs\.?|₹|\$)\s*[\d.,]+\s*(?:at|in|on|for|to)?\s+"#,
            with: "", options: .regularExpression)

        // 3. Leading merchant/terminal ID: "899795-NAME", "0012345 NAME"
        s = s.replacingOccurrences(
            of: #"^\s*\d{3,}\s*[-–—*:/|.]?\s*"#,
            with: "", options: .regularExpression)

        // 4. Trailing reference/terminal ID: "NAME-4455667"
        s = s.replacingOccurrences(
            of: #"\s*[-–—*:/|]?\s*\d{5,}\s*$"#,
            with: "", options: .regularExpression)

        // 5. Long bare alphanumeric codes that aren't words (e.g. "X7H29ADK1")
        s = s.replacingOccurrences(
            of: #"\b(?=[A-Z0-9]*\d)[A-Z0-9]{6,}\b"#,
            with: "", options: .regularExpression)

        // 6. Card masks that sometimes ride along: "4228**** ****2787"
        s = s.replacingOccurrences(
            of: #"[0-9X\*]{4,}[\s\-]?(?:[0-9X\*]{2,}[\s\-]?)+"#,
            with: "", options: .regularExpression)

        // 7. Tidy separators and whitespace.
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " .,-–—*:;/|#"))

        // 8. Drop a dangling truncated fragment left by the bank's field
        //    width, e.g. "…HYPERMARKET o" or "…AL TAMAM LLC Ghu".
        let words = s.split(separator: " ").map(String.init)
        if words.count >= 3, let last = words.last {
            let isShortLower = last.count <= 2 && last == last.lowercased()
            let isMixedStub  = last.count == 3
                && last.rangeOfCharacter(from: .lowercaseLetters) != nil
                && last.rangeOfCharacter(from: .uppercaseLetters) != nil
            if isShortLower || isMixedStub {
                s = words.dropLast().joined(separator: " ")
            }
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Bank

    private static func detectBank(in text: String) -> String {
        let lower = text.lowercased()
        let banks: [(keywords: [String], name: String)] = [
            (["sbi", "state bank"], "SBI"),
            (["hdfc"], "HDFC"),
            (["icici"], "ICICI"),
            (["axis"], "Axis"),
            (["kotak"], "Kotak"),
            (["bob", "bank of baroda"], "Bank of Baroda"),
            (["pnb", "punjab national"], "PNB"),
            (["canara"], "Canara"),
            (["union bank"], "Union Bank"),
            (["indian bank"], "Indian Bank"),
            (["idbi"], "IDBI"),
            (["yes bank"], "Yes Bank"),
            (["federal"], "Federal Bank"),
            (["indusind"], "IndusInd"),
            (["rbl"], "RBL"),
            (["iob", "indian overseas"], "IOB"),
            (["boi", "bank of india"], "Bank of India"),
            (["bank muscat", "bankmuscat"], "Bank Muscat"),
            (["national bank of oman", "nbo"], "NBO"),
            (["oman arab bank", "oab"], "OAB"),
            (["bank dhofar", "bankdhofar"], "Bank Dhofar"),
            (["hsbc"], "HSBC"),
            (["standard chartered", "stanchart"], "Standard Chartered"),
            (["citibank", "citi"], "Citibank"),
            (["emirates nbd", "enbd"], "Emirates NBD"),
            (["mashreq"], "Mashreq"),
            (["adcb"], "ADCB"),
            (["fab", "first abu dhabi"], "FAB"),
            (["al rajhi", "alrajhi"], "Al Rajhi"),
            (["snb", "saudi national"], "SNB"),
            (["dbs"], "DBS"),
            (["ocbc"], "OCBC"),
            (["uob"], "UOB"),
            (["maybank"], "Maybank"),
        ]
        for bank in banks {
            for keyword in bank.keywords {
                if lower.contains(keyword) { return bank.name }
            }
        }
        return "Bank"
    }

    // MARK: - Account

    private static func extractAccount(from text: String) -> String {
        let patterns = [
            #"(?i)(?:a/c|acct|account)(?:\s*(?:number|no\.?))?\s*[:#]?\s*\d*[Xx*]+(\d{4})"#,
            #"(?:XX|xx|\*\*)\d*(\d{4})"#,
            #"(?i)(?:a/c|acct|account)(?:\s*(?:number|no\.?))?\s*[:#]?\s*(\d{4})"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return ""
    }

    // MARK: - Card number

    /// Pulls the masked card number as printed in the message,
    /// e.g. "Your Debit card number 4228**** ****2787" → "4228**** ****2787".
    private static func extractCardNumber(from text: String) -> String {
        let patterns = [
            #"(?i)card\s*(?:number|no\.?)?\s*[:#]?\s*((?:[0-9Xx\*]{4}[\s\-]?){2,4}[0-9]{2,4})"#,
            #"(?i)card\s+ending\s+(?:with|in)\s+[Xx\*]*(\d{4})"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    // MARK: - Transaction date/time

    /// Pulls the raw "Date/Time : 13 JUL 26 23:11" style value from the message.
    /// Captures only a date/time-shaped token — never free text — so it stays
    /// correct even when the whole email body is flattened onto one line.
    private static func extractDateTimeText(from text: String) -> String {
        let patterns = [
            // "13 JUL 26 23:11", "13-Jul-2026 23:11:05", "13/07/26, 23:11"
            #"(?i)date\s*/?\s*time\s*[:\-]\s*(\d{1,2}[ \-/](?:[A-Za-z]{3,9}|\d{1,2})[ \-/]\d{2,4}(?:[ ,]*(?:at\s+)?\d{1,2}:\d{2}(?::\d{2})?)?)"#,
            #"(?i)\bon\s+(\d{1,2}[-/][A-Za-z0-9]{2,3}[-/]\d{2,4}(?:[ ,]+\d{1,2}:\d{2}(?::\d{2})?)?)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    // MARK: - Balance

    private static func extractBalance(from text: String) -> Double? {
        let lower = text.lowercased()
        guard let balIdx = lower.range(of: "balance") ?? lower.range(of: "bal") else { return nil }
        let afterBal = String(text[balIdx.upperBound...])

        let allCurrencyRegex = currencyPatterns.map { $0.regex }.joined(separator: "|")
        let pattern = "(?:\(allCurrencyRegex)|:|-|is)\\s*([0-9,]+(?:\\.[0-9]{1,3})?)"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: afterBal, range: NSRange(afterBal.startIndex..<afterBal.endIndex, in: afterBal)),
           let range = Range(match.range(at: 1), in: afterBal) {
            let numStr = String(afterBal[range]).replacingOccurrences(of: ",", with: "")
            return Double(numStr)
        }
        return nil
    }

    // MARK: - Category

    static func categorizeWithConfidence(merchant: String, text: String) -> (ExpenseCategory, ParsedTransaction.ConfidenceLevel) {
        let lower = (merchant + " " + text).lowercased()

        let groceryKeywords = ["grocer", "grocery", "bigbasket", "blinkit", "zepto",
                               "instamart", "dunzo", "lulu", "carrefour", "supermarket",
                               "hypermarket", "dmart", "reliance fresh", "more supermarket",
                               "spar", "nesto", "al fair"]
        let foodKeywords = ["swiggy", "zomato", "food", "restaurant", "cafe", "coffee",
                            "starbucks", "dominos", "pizza", "mcdonald", "kfc", "burger",
                            "eat", "dine", "kitchen", "bakery"]
        let transportKeywords = ["uber", "ola", "rapido", "metro", "railway", "irctc",
                                 "petrol", "fuel", "diesel", "parking", "toll", "redbus",
                                 "makemytrip", "goibibo", "cleartrip", "indigo", "spicejet",
                                 "air india", "vistara", "taxi", "cab", "marhaba",
                                 "oman air", "salam air", "emirates", "qatar airways",
                                 "fly dubai", "etihad"]
        let shoppingKeywords = ["amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa",
                                "tatacliq", "snapdeal", "shoppers", "mall", "store",
                                "reliance", "croma", "vijay sales", "dress", "clothing",
                                "cosmetic", "beauty", "fashion", "garment", "apparel",
                                "noon", "namshi", "shein"]
        let healthKeywords = ["pharmacy", "medical", "hospital", "doctor", "clinic",
                              "apollo", "medplus", "netmeds", "pharmeasy", "1mg",
                              "lab", "diagnostic", "health", "medicine"]
        let entertainmentKeywords = ["netflix", "hotstar", "prime video", "spotify",
                                     "youtube", "disney", "jio cinema", "zee5", "sony liv",
                                     "movie", "cinema", "pvr", "inox", "bookmyshow",
                                     "game", "play station", "xbox", "shahid", "osn"]
        let utilityKeywords = ["electricity", "water bill", "gas bill", "broadband", "wifi",
                               "airtel", "jio", "vodafone", "vi ", "bsnl", "ooredoo", "omantel",
                               "rent", "maintenance", "emi", "loan", "insurance",
                               "lic", "bill", "recharge", "dth", "tata sky",
                               "school fee", "tuition", "education", "college", "university"]

        if groceryKeywords.contains(where: { lower.contains($0) }) { return (.grocery, .high) }
        if foodKeywords.contains(where: { lower.contains($0) }) { return (.food, .high) }
        if transportKeywords.contains(where: { lower.contains($0) }) { return (.transport, .high) }
        if shoppingKeywords.contains(where: { lower.contains($0) }) { return (.shopping, .high) }
        if healthKeywords.contains(where: { lower.contains($0) }) { return (.health, .high) }
        if entertainmentKeywords.contains(where: { lower.contains($0) }) { return (.entertainment, .high) }
        if utilityKeywords.contains(where: { lower.contains($0) }) { return (.utilities, .high) }

        return (.other, .low)
    }

    static func categorize(merchant: String) -> ExpenseCategory {
        categorizeWithConfidence(merchant: merchant, text: "").0
    }
}
