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
}

struct BankSMSParser {

    static func parse(_ text: String) -> ParsedTransaction? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeBankSMS(trimmed) else { return nil }

        guard let amount = extractAmount(from: trimmed) else { return nil }
        let isCredit = detectCredit(in: trimmed)
        let merchant = extractMerchant(from: trimmed)
        let category = categorize(merchant: merchant)
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
            rawText: trimmed
        )
    }

    static func looksLikeBankSMS(_ text: String) -> Bool {
        let lower = text.lowercased()
        let hasAmount = lower.contains("rs") || lower.contains("inr") || lower.contains("₹")
        let hasAction = lower.contains("debit") || lower.contains("credit") ||
                        lower.contains("spent") || lower.contains("received") ||
                        lower.contains("withdrawn") || lower.contains("transferred") ||
                        lower.contains("sent") || lower.contains("paid") ||
                        lower.contains("refund") || lower.contains("deposit")
        let hasAccount = lower.contains("a/c") || lower.contains("acct") ||
                         lower.contains("account") || lower.contains("card") ||
                         lower.contains("xx") || lower.contains("**")
        return hasAmount && (hasAction || hasAccount)
    }

    // MARK: - Amount

    private static func extractAmount(from text: String) -> Double? {
        let patterns = [
            #"(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)"#,
            #"([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:Rs\.?|INR|₹)"#,
            #"(?:amount|amt)\s*(?:of\s*)?(?:Rs\.?|INR|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression, range: text.startIndex..<text.endIndex) {
                let matched = String(text[match])
                let digits = matched.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                if let val = Double(digits), val > 0 {
                    return val
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let numRange = Range(match.range(at: 1), in: text) {
                let numStr = String(text[numRange]).replacingOccurrences(of: ",", with: "")
                if let val = Double(numStr), val > 0 {
                    return val
                }
            }
        }
        return nil
    }

    // MARK: - Credit / Debit

    private static func detectCredit(in text: String) -> Bool {
        let lower = text.lowercased()
        let creditWords = ["credited", "credit", "received", "deposited", "refund",
                           "cash back", "cashback", "reversed", "added"]
        let debitWords = ["debited", "debit", "spent", "withdrawn", "sent",
                          "paid", "purchase", "transferred", "payment"]

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
        return creditPos < debitPos
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

                let stopWords = ["avl", "bal", "available", "balance", "ref", "upi", "neft", "imps", "a/c"]
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
        return "Bank Transaction"
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
            #"(?:XX|xx|\*\*|a/c\s*|acct\s*|account\s*)(\d{4})"#,
            #"(\d{4})(?=\s|\.|\)|$)"#,
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
        guard let balIdx = lower.range(of: "bal") ?? lower.range(of: "balance") else { return nil }
        let afterBal = String(text[balIdx.upperBound...])

        if let regex = try? NSRegularExpression(pattern: #"(?:Rs\.?|INR|₹|:|-)\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: afterBal, range: NSRange(afterBal.startIndex..<afterBal.endIndex, in: afterBal)),
           let range = Range(match.range(at: 1), in: afterBal) {
            let numStr = String(afterBal[range]).replacingOccurrences(of: ",", with: "")
            return Double(numStr)
        }
        return nil
    }

    // MARK: - Category

    static func categorize(merchant: String) -> ExpenseCategory {
        let lower = merchant.lowercased()

        let foodKeywords = ["swiggy", "zomato", "food", "restaurant", "cafe", "coffee",
                            "starbucks", "dominos", "pizza", "mcdonald", "kfc", "burger",
                            "eat", "dine", "kitchen", "bakery", "dairy", "grocer", "bigbasket",
                            "blinkit", "zepto", "instamart", "dunzo"]
        let transportKeywords = ["uber", "ola", "rapido", "metro", "railway", "irctc",
                                 "petrol", "fuel", "diesel", "parking", "toll", "redbus",
                                 "makemytrip", "goibibo", "cleartrip", "indigo", "spicejet",
                                 "air india", "vistara"]
        let shoppingKeywords = ["amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa",
                                "tatacliq", "snapdeal", "shoppers", "mall", "store",
                                "reliance", "croma", "vijay sales"]
        let healthKeywords = ["pharmacy", "medical", "hospital", "doctor", "clinic",
                              "apollo", "medplus", "netmeds", "pharmeasy", "1mg",
                              "lab", "diagnostic", "health"]
        let entertainmentKeywords = ["netflix", "hotstar", "prime video", "spotify",
                                     "youtube", "disney", "jio cinema", "zee5", "sony liv",
                                     "movie", "cinema", "pvr", "inox", "bookmyshow",
                                     "game", "play station", "xbox"]
        let utilityKeywords = ["electricity", "water", "gas", "broadband", "wifi",
                               "airtel", "jio", "vodafone", "vi ", "bsnl",
                               "rent", "maintenance", "emi", "loan", "insurance",
                               "lic", "bill", "recharge", "dth", "tata sky"]

        if foodKeywords.contains(where: { lower.contains($0) }) { return .food }
        if transportKeywords.contains(where: { lower.contains($0) }) { return .transport }
        if shoppingKeywords.contains(where: { lower.contains($0) }) { return .shopping }
        if healthKeywords.contains(where: { lower.contains($0) }) { return .health }
        if entertainmentKeywords.contains(where: { lower.contains($0) }) { return .entertainment }
        if utilityKeywords.contains(where: { lower.contains($0) }) { return .utilities }

        return .other
    }
}
