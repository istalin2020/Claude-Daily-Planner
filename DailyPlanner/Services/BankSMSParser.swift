import Foundation

struct ParsedTransaction {
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

    enum ConfidenceLevel {
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
            confidenceCategory: catConfidence
        )
    }

    static func looksLikeBankSMS(_ text: String) -> Bool {
        let lower = text.lowercased()
        let allCurrencyCodes = ["rs", "inr", "₹", "omr", "aed", "sar", "usd", "$",
                                "eur", "€", "gbp", "£", "kwd", "bhd", "qar",
                                "sgd", "myr", "rm", "pkr", "bdt", "lkr", "npr"]
        let hasAmount = allCurrencyCodes.contains(where: { lower.contains($0) })
        let hasAction = lower.contains("debit") || lower.contains("credit") ||
                        lower.contains("spent") || lower.contains("received") ||
                        lower.contains("withdrawn") || lower.contains("transferred") ||
                        lower.contains("sent") || lower.contains("paid") ||
                        lower.contains("refund") || lower.contains("deposit") ||
                        lower.contains("purchase") || lower.contains("transaction")
        let hasAccount = lower.contains("a/c") || lower.contains("acct") ||
                         lower.contains("account") || lower.contains("card") ||
                         lower.contains("xx") || lower.contains("**") ||
                         lower.contains("balance") || lower.contains("bal")
        return hasAmount && (hasAction || hasAccount)
    }

    // MARK: - Amount

    private static func extractAmount(from text: String) -> (Double, String)? {
        for entry in currencyPatterns {
            let patterns = [
                "\(entry.regex)\\s*([0-9,]+(?:\\.[0-9]{1,3})?)",
                "([0-9,]+(?:\\.[0-9]{1,3})?)\\s*\(entry.regex)",
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..<text.endIndex, in: text)
                    if let match = regex.firstMatch(in: text, range: range) {
                        for g in 1..<match.numberOfRanges {
                            if let r = Range(match.range(at: g), in: text) {
                                let str = String(text[r])
                                let digits = str.replacingOccurrences(of: ",", with: "")
                                if let val = Double(digits), val > 0 {
                                    return (val, entry.codes[0])
                                }
                            }
                        }
                    }
                }
            }
        }

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

    // MARK: - Credit / Debit

    private static func detectCreditWithConfidence(in text: String) -> (Bool, ParsedTransaction.ConfidenceLevel) {
        let lower = text.lowercased()
        let creditWords = ["credited", "credit", "received", "deposited", "refund",
                           "cash back", "cashback", "reversed", "added", "incoming"]
        let debitWords = ["debited", "debit", "spent", "withdrawn", "sent",
                          "paid", "purchase", "transferred", "payment", "outgoing"]

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
                if merchant.count >= 2 && merchant.count <= 40 {
                    return merchant
                }
            }
        }
        return ""
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
            #"(?:a/c|acct|account)\s*[:#]?\s*\d*[Xx*]+(\d{4})"#,
            #"(?:XX|xx|\*\*)\d*(\d{4})"#,
            #"(?:a/c|acct|account)\s*(\d{4})"#,
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

        let foodKeywords = ["swiggy", "zomato", "food", "restaurant", "cafe", "coffee",
                            "starbucks", "dominos", "pizza", "mcdonald", "kfc", "burger",
                            "eat", "dine", "kitchen", "bakery", "dairy", "grocer", "grocery",
                            "bigbasket", "blinkit", "zepto", "instamart", "dunzo",
                            "lulu", "carrefour", "supermarket", "hypermarket"]
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
