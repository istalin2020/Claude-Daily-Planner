import UIKit

/// Real app icons for the subscriptions page.
///
/// Two sources, both Apple's own servers, so nothing third-party is bundled
/// in the app:
///
/// * App Store receipts carry the app's icon (`iconURL` on the plan).
/// * For a plan paid by card — Netflix, Omantel, OpenAI — the icon of that
///   company's iPhone app is looked up once in the public iTunes Search API
///   and remembered.
///
/// Images are kept in memory and on disk, and decoded off the main thread:
/// downloading or decoding while the list scrolls is what made it stutter.
final class SubscriptionIconStore: @unchecked Sendable {
    static let shared = SubscriptionIconStore()

    private let memory = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    /// Brand name → icon URL, persisted. A failed lookup is only remembered
    /// for this launch, so a network hiccup doesn't hide the icon for good.
    private var lookups: [String: String]
    private var failedLookups: Set<String> = []
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private let lookupsKey = "subscriptionIconLookups.v1"
    private let directory: URL

    private init() {
        lookups = UserDefaults.standard.dictionary(forKey: lookupsKey) as? [String: String] ?? [:]
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("SubscriptionIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 120
    }

    // MARK: - Synchronous (for the first frame)

    /// An icon already in memory, so a row that scrolls back into view shows
    /// it immediately instead of flashing the placeholder.
    func cachedImage(url: String?, brand: String?) -> UIImage? {
        guard let url = url ?? brand.flatMap(lookedUpURL) else { return nil }
        return memory.object(forKey: url as NSString)
    }

    private func lookedUpURL(_ brand: String) -> String? {
        lock.withLock { lookups[brand] }
    }

    // MARK: - Loading

    /// The icon for a plan: its receipt icon, else its brand's App Store icon.
    func image(url: String?, brand: String?) async -> UIImage? {
        if let url = url { return await image(at: url) }
        guard let brand = brand, let found = await lookUp(brand) else { return nil }
        return await image(at: found)
    }

    private func image(at url: String) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSString) { return hit }

        let file = directory.appendingPathComponent(Self.fileName(for: url))
        // One download per icon, however many rows ask for it at once.
        let task: Task<UIImage?, Never> = lock.withLock {
            if let running = inFlight[url] { return running }
            let started = Task.detached(priority: .utility) { () -> UIImage? in
                if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
                    return img.preparingForDisplay() ?? img
                }
                guard let remote = URL(string: url),
                      let fetched = try? await URLSession.shared.data(from: remote),
                      (fetched.1 as? HTTPURLResponse)?.statusCode == 200,
                      let img = UIImage(data: fetched.0) else { return nil }
                try? fetched.0.write(to: file, options: .atomic)
                return img.preparingForDisplay() ?? img
            }
            inFlight[url] = started
            return started
        }

        let result = await task.value
        lock.withLock { inFlight[url] = nil }
        if let result = result { memory.setObject(result, forKey: url as NSString) }
        return result
    }

    // MARK: - App Store lookup

    /// What to search for, and whose app it must be. The seller check keeps a
    /// look-alike app's icon from being shown for the real service.
    private static let searches: [String: (term: String, sellers: [String])] = [
        "Netflix":       ("Netflix", ["netflix"]),
        "Amazon Prime":  ("Prime Video", ["amzn", "amazon"]),
        "Disney+":       ("Disney+", ["disney"]),
        "Spotify":       ("Spotify", ["spotify"]),
        "YouTube":       ("YouTube", ["google"]),
        "Shahid":        ("Shahid", ["mbc"]),
        "OSN":           ("OSN+", ["osn"]),
        "Anghami":       ("Anghami", ["anghami"]),
        "OpenAI":        ("ChatGPT", ["openai"]),
        "Anthropic":     ("Claude by Anthropic", ["anthropic"]),
        "GitHub":        ("GitHub", ["github"]),
        "Higgsfield":    ("Higgsfield", ["higgsfield"]),
        "Google One":    ("Google One", ["google"]),
        "Microsoft 365": ("Microsoft 365 Copilot", ["microsoft"]),
        "Adobe":         ("Adobe Creative Cloud", ["adobe"]),
        "Dropbox":       ("Dropbox", ["dropbox"]),
        "Notion":        ("Notion", ["notion"]),
        "Canva":         ("Canva", ["canva"]),
        "LinkedIn":      ("LinkedIn", ["linkedin"]),
        "Zoom":          ("Zoom Workplace", ["zoom"]),
        "WhatsApp":      ("WhatsApp Messenger", ["whatsapp"]),
        "Ooredoo":       ("Ooredoo Oman", ["ooredoo", "omani qatari"]),
        "Omantel":       ("Omantel", ["omantel", "oman telecommunications"]),
    ]

    static func canLookUp(_ brand: String) -> Bool { searches[brand] != nil }

    private func lookUp(_ brand: String) async -> String? {
        let (known, failed) = lock.withLock { (lookups[brand], failedLookups.contains(brand)) }
        if let known = known { return known }
        guard !failed, let search = Self.searches[brand] else { return nil }

        // The local storefront first (Omantel isn't in the US store), then US.
        let local = Locale.current.region?.identifier.lowercased() ?? "us"
        for country in local == "us" ? ["us"] : [local, "us"] {
            if let url = await search(search.term, sellers: search.sellers, country: country) {
                let snapshot: [String: String] = lock.withLock {
                    lookups[brand] = url
                    return lookups
                }
                UserDefaults.standard.set(snapshot, forKey: lookupsKey)
                return url
            }
        }
        lock.withLock { _ = failedLookups.insert(brand) }
        return nil
    }

    private struct SearchResponse: Decodable {
        struct App: Decodable {
            let trackName: String?
            let sellerName: String?
            let artistName: String?
            let artworkUrl100: String?
            let artworkUrl512: String?
        }
        let results: [App]
    }

    private func search(_ term: String, sellers: [String], country: String) async -> String? {
        var parts = URLComponents(string: "https://itunes.apple.com/search")!
        parts.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: "8"),
        ]
        guard let url = parts.url,
              let fetched = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: fetched.0) else { return nil }

        let app = decoded.results.first { app in
            let owner = ((app.sellerName ?? "") + " " + (app.artistName ?? "")).lowercased()
            return sellers.contains { owner.contains($0) }
        }
        // 100px is blurry on a Retina tile; Apple serves any size from the
        // same path.
        return (app?.artworkUrl512 ?? app?.artworkUrl100)?
            .replacingOccurrences(of: #"/\d+x\d+bb\."#, with: "/128x128bb.",
                                  options: .regularExpression)
    }

    // MARK: -

    /// A stable file name (FNV-1a), unlike `hashValue`, which changes on
    /// every launch.
    private static func fileName(for url: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in url.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(hash, radix: 16) + ".img"
    }
}
