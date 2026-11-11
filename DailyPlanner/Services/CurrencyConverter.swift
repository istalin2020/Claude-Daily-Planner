import Foundation

struct CurrencyConverter {

    // Approximate rates to 1 USD (May 2025 baseline).
    // Used only for SMS import conversion estimates.
    private static let ratesToUSD: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.92,
        "GBP": 0.79,
        "JPY": 155.0,
        "CNY": 7.25,
        "INR": 83.5,
        "AUD": 1.55,
        "CAD": 1.37,
        "CHF": 0.90,
        "KRW": 1350.0,
        "BRL": 5.10,
        "MXN": 17.2,
        "AED": 3.6725,
        "SAR": 3.75,
        "SGD": 1.35,
        "HKD": 7.82,
        "NZD": 1.68,
        "ZAR": 18.5,
        "TRY": 32.0,
        "PLN": 4.05,
        "MYR": 4.72,
        "THB": 35.5,
        "IDR": 15800.0,
        "PHP": 56.5,
        "VND": 25400.0,
        "EGP": 47.5,
        "PKR": 278.0,
        "BDT": 110.0,
        "NGN": 1550.0,
        "QAR": 3.64,
        "KWD": 0.307,
        "BHD": 0.376,
        "OMR": 0.385,
        "NOK": 10.8,
        "SEK": 10.7,
        "DKK": 6.88,
        "LKR": 300.0,
        "NPR": 133.5,
        "Rs": 83.5,
        "RM": 4.72,
    ]

    static func convert(amount: Double, from source: String, to target: String) -> Double? {
        let src = normalise(source)
        let tgt = normalise(target)
        guard src != tgt,
              let srcRate = ratesToUSD[src],
              let tgtRate = ratesToUSD[tgt] else { return nil }
        let usd = amount / srcRate
        return usd * tgtRate
    }

    static func needsConversion(detected: String, local: String) -> Bool {
        normalise(detected) != normalise(local) && !detected.isEmpty
    }

    private static func normalise(_ code: String) -> String {
        let upper = code.uppercased().trimmingCharacters(in: .whitespaces)
        switch upper {
        case "RS", "₹":  return "INR"
        case "$":         return "USD"
        case "€":         return "EUR"
        case "£":         return "GBP"
        default:          return upper
        }
    }
}
