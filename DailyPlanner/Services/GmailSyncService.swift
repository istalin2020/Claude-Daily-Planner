import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

// MARK: - Configuration
//
// Gmail access requires a one-time Google Cloud setup that only YOU can do —
// Apple/Google will not allow API access without your own OAuth credentials:
//
//   1. Go to https://console.cloud.google.com → create a project.
//   2. APIs & Services → Library → enable the "Gmail API".
//   3. APIs & Services → OAuth consent screen → configure (External, add the
//      gmail.readonly scope, add your Google account as a test user).
//   4. APIs & Services → Credentials → Create Credentials → OAuth client ID →
//      Application type: iOS → set your app's Bundle ID.
//   5. Copy the generated Client ID and paste it into `clientID` below.
//   6. In Xcode → Info.plist a matching URL scheme (the reversed client ID) is
//      already templated — replace the placeholder with your reversed client ID.
//
// Once `clientID` is filled in, the entire flow below works end-to-end.
enum GmailConfig {

    /// ← PASTE YOUR iOS OAuth Client ID HERE.
    /// Looks like: "1234567890-abcdefghijklmnop.apps.googleusercontent.com"
    static let clientID = "295054109320-dnj7a038qmm5lk6dqj5hv5bm7o4fe4kr.apps.googleusercontent.com"

    static let scope = "https://www.googleapis.com/auth/gmail.readonly"

    static var isConfigured: Bool { !clientID.isEmpty }

    /// Reversed client ID — the custom URL scheme Google redirects back to.
    static var reversedClientID: String {
        let core = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(core)"
    }

    static var redirectURI: String { "\(reversedClientID):/oauth2redirect" }
}

// MARK: - A single transaction candidate pulled from Gmail
/// Codable so unreviewed candidates can be persisted and the review
/// resumed exactly where the user left off, even after an app restart.
struct GmailCandidate: Identifiable, Codable {
    let id: String          // Gmail message ID (used for de-duplication)
    let date: Date          // when the bank email was received
    let parsed: ParsedTransaction
}

// MARK: - Sync result handed back to the UI
struct GmailSyncResult {
    /// Transactions auto-added (credits, and debits with a confident category).
    var autoAdded: [GmailCandidate] = []
    /// Debit transactions whose category is unknown — the user must review.
    var needsReview: [GmailCandidate] = []
    /// Newest email epoch seen this run (to advance the incremental cursor).
    var newestEpoch: Double = 0
}

enum GmailSyncError: LocalizedError {
    case notConfigured
    case cancelled
    case authFailed(String)
    case network(String)
    case noRefreshToken
    case reconnectNeeded

    var errorDescription: String? {
        switch self {
        case .notConfigured:   return "Gmail sync isn't configured yet. Add your Google OAuth Client ID in GmailSyncService.swift."
        case .cancelled:       return "Sign-in was cancelled."
        case .authFailed(let m): return "Google sign-in failed: \(m)"
        case .network(let m):  return "Couldn't reach Gmail: \(m)"
        case .noRefreshToken:  return "Gmail isn't connected. Please connect your account first."
        case .reconnectNeeded: return "Your Gmail connection has expired. Tap “Reconnect Gmail” to sign in again."
        }
    }
}

// MARK: - Gmail Sync Service
@MainActor
final class GmailSyncService: NSObject, ObservableObject {

    static let shared = GmailSyncService()

    private let keychainRefreshKey = "gmail_refresh_token"
    private var accessToken: String?
    private var accessTokenExpiry: Date = .distantPast

    var isConnected: Bool { KeychainHelper.read(keychainRefreshKey) != nil }

    // MARK: Connect (first-time OAuth)

    /// Presents Google sign-in and stores the refresh token.
    /// Returns the connected email address.
    func connect() async throws -> String {
        guard GmailConfig.isConfigured else { throw GmailSyncError.notConfigured }

        let verifier  = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let code = try await authorize(challenge: challenge)
        let tokens = try await exchangeCode(code, verifier: verifier)

        if let refresh = tokens.refreshToken {
            KeychainHelper.save(refresh, for: keychainRefreshKey)
        }
        accessToken = tokens.accessToken
        accessTokenExpiry = Date().addingTimeInterval(tokens.expiresIn - 60)

        return tokens.email ?? "Gmail account"
    }

    func disconnect() {
        KeychainHelper.delete(keychainRefreshKey)
        accessToken = nil
        accessTokenExpiry = .distantPast
    }

    // MARK: Fetch transactions within a date window

    /// Reads bank emails received within [startDate, endDate) — typically one
    /// calendar month — parses each into a transaction candidate, and skips
    /// already-processed IDs so re-syncing the same month never duplicates.
    func fetchTransactions(from startDate: Date,
                           to endDate: Date,
                           alreadyProcessed: Set<String>) async throws -> [GmailCandidate] {
        try await ensureAccessToken()

        let after  = Int(startDate.timeIntervalSince1970)
        let before = Int(endDate.timeIntervalSince1970)

        // Ask Gmail for transaction-shaped mail only, and let Gmail's own
        // classifier keep Promotions/Social/Forums out — that alone removes
        // most newsletters and sweepstakes before we ever parse them.
        //
        // The verb list has to cover how each bank actually words its alerts.
        // Bank Muscat writes "card ... used for USD 5.000" for credit cards and
        // "has been reversed" for refunds; neither contains any of the original
        // verbs, so those emails were never even fetched. Over-fetching is
        // cheap — BankSMSParser.looksLikeBankSMS is what decides.
        let verbs = "(debited OR credited OR withdrawn OR spent OR utilised OR utilized "
                  + "OR charged OR transferred OR deposited OR used OR reversed OR reversal "
                  + "OR refunded OR purchase OR payment)"
        let refs  = "(account OR \"a/c\" OR card OR balance)"

        // Subscription receipts carry none of the bank wording above, so they
        // need their own arm of the query. Apple's receipts are the only way
        // App Store subscriptions can ever reach this app.
        let subs = Self.subscriptionQueryArm
        let excludeCategories = "-category:promotions -category:social -category:forums"
        let excludeNoise = "-\"no purchase necessary\" -sweepstakes -\"gift card\" -newsletter -\"view in browser\" -\"unsubscribe from\""

        // Apple mail gets its own arm with no category filter: Gmail sometimes
        // files Apple receipts under Promotions, and they are the only record
        // of an App Store subscription there is.
        let query = "after:\(after) before:\(before) ((\(verbs) \(refs)) OR \(subs)) "
                  + "\(excludeCategories) \(excludeNoise)"
        // Apple mail is fetched separately and without the category filter:
        // Gmail sometimes files Apple receipts under Promotions, and they are
        // the only record of an App Store subscription there is.
        let appleQuery = "after:\(after) before:\(before) from:apple.com"

        var seen = Set<String>()
        var ids: [String] = []
        for q in [query, appleQuery] {
            for id in try await listMessageIDs(query: q) where seen.insert(id).inserted {
                ids.append(id)
            }
        }
        var candidates: [GmailCandidate] = []
        var events: [SubscriptionEvent] = []

        for id in ids where !alreadyProcessed.contains(id) {
            guard let msg = try? await fetchMessage(id: id) else { continue }

            // A receipt or cancellation notice is read first, and never becomes
            // an expense. The bank alert for the same charge is the expense;
            // booking the receipt too counted every subscription twice, since
            // a USD receipt can't be matched to an OMR alert to the baisa.
            if let event = SubscriptionEmailParser.event(body: msg.body, sender: msg.sender,
                                                         subject: msg.subject,
                                                         receivedOn: msg.date) {
                events.append(event)
                continue
            }

            if BankSMSParser.looksLikeBankSMS(msg.body),
               let parsed = BankSMSParser.parse(msg.body) {
                candidates.append(GmailCandidate(id: id, date: msg.date, parsed: parsed))
            }
        }

        lastSubscriptionEvents = events
        return candidates
    }

    /// Subscription receipts and cancellations read during the last fetch.
    /// Held here rather than threaded through GmailCandidate because they are
    /// not transactions and never enter the expense review queue.
    private(set) var lastSubscriptionEvents: [SubscriptionEvent] = []

    /// Gmail terms that catch subscription receipts and cancellations. They
    /// carry none of the bank-alert wording, so without this arm they are
    /// never fetched at all.
    private static let subscriptionQueryArm =
        "(subscription OR membership OR renewal OR renews OR renewed OR \"auto-renew\" "
      + "OR \"automatically renew\" OR \"billing period\" OR \"apple.com/bill\" "
      + "OR cancelled OR canceled)"

    /// Looks back over the last `monthsBack` months for subscription receipts
    /// and cancellations only — no bank alerts, so nothing enters the expense
    /// review.
    ///
    /// The regular sync covers only the current or previous month, so a
    /// yearly plan whose single receipt arrived months ago would otherwise
    /// never be found. Safe to repeat: storing what it finds is idempotent.
    func scanForSubscriptions(monthsBack: Int = 13) async throws -> [SubscriptionEvent] {
        try await ensureAccessToken()
        let start = Calendar.current.date(byAdding: .month, value: -monthsBack, to: Date()) ?? Date()
        let after = Int(start.timeIntervalSince1970)

        let general = "after:\(after) \(Self.subscriptionQueryArm) "
                    + "-category:social -category:forums"
        let apple   = "after:\(after) from:apple.com"

        var seen = Set<String>()
        var ids: [String] = []
        for query in [apple, general] {
            for id in try await listMessageIDs(query: query) where seen.insert(id).inserted {
                ids.append(id)
            }
        }

        var events: [SubscriptionEvent] = []
        for id in ids {
            guard let msg = try? await fetchMessage(id: id) else { continue }
            if let event = SubscriptionEmailParser.event(body: msg.body, sender: msg.sender,
                                                         subject: msg.subject,
                                                         receivedOn: msg.date) {
                events.append(event)
            }
        }
        return events
    }

    // MARK: - OAuth: authorization request

    private func authorize(challenge: String) async throws -> String {
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",             value: GmailConfig.clientID),
            .init(name: "redirect_uri",          value: GmailConfig.redirectURI),
            .init(name: "response_type",         value: "code"),
            .init(name: "scope",                 value: GmailConfig.scope),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type",           value: "offline"),
            .init(name: "prompt",                value: "consent")
        ]
        let authURL = comps.url!
        let scheme  = GmailConfig.reversedClientID

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL, callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GmailSyncError.cancelled)
                    } else {
                        continuation.resume(throwing: GmailSyncError.authFailed(error.localizedDescription))
                    }
                    return
                }
                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GmailSyncError.authFailed("No authorization code returned."))
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - OAuth: token exchange & refresh

    private struct TokenResponse {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval
        let email: String?
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        let params = [
            "code":          code,
            "client_id":     GmailConfig.clientID,
            "redirect_uri":  GmailConfig.redirectURI,
            "grant_type":    "authorization_code",
            "code_verifier": verifier
        ]
        return try await postToken(params)
    }

    private func ensureAccessToken() async throws {
        if let token = accessToken, Date() < accessTokenExpiry, !token.isEmpty { return }
        guard let refresh = KeychainHelper.read(keychainRefreshKey) else {
            throw GmailSyncError.noRefreshToken
        }
        let params = [
            "refresh_token": refresh,
            "client_id":     GmailConfig.clientID,
            "grant_type":    "refresh_token"
        ]
        do {
            let tokens = try await postToken(params)
            accessToken = tokens.accessToken
            accessTokenExpiry = Date().addingTimeInterval(tokens.expiresIn - 60)
        } catch let GmailSyncError.authFailed(message) {
            // Google revokes refresh tokens for "Testing" mode apps after ~7 days
            // (and on password changes / revocation). It reports this as
            // "invalid_grant". Treat that as a friendly "reconnect" prompt rather
            // than a scary auth error, and clear the dead token.
            if message.contains("invalid_grant") {
                disconnect()
                throw GmailSyncError.reconnectNeeded
            }
            throw GmailSyncError.authFailed(message)
        }
    }

    private func postToken(_ params: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown token error"
            throw GmailSyncError.authFailed(msg)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else {
            throw GmailSyncError.authFailed("Malformed token response.")
        }
        let refresh   = json["refresh_token"] as? String
        let expires   = (json["expires_in"] as? Double) ?? 3600
        let idToken   = json["id_token"] as? String
        let email     = idToken.flatMap(Self.email(fromIDToken:))
        return TokenResponse(accessToken: access, refreshToken: refresh, expiresIn: expires, email: email)
    }

    // MARK: - Gmail REST calls

    private func listMessageIDs(query: String) async throws -> [String] {
        var ids: [String] = []
        var pageToken: String? = nil
        var pages = 0

        repeat {
            var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
            comps.queryItems = [
                .init(name: "q", value: query),
                .init(name: "maxResults", value: "100")
            ]
            if let token = pageToken {
                comps.queryItems?.append(.init(name: "pageToken", value: token))
            }
            let json = try await authorizedGET(comps.url!)
            if let messages = json["messages"] as? [[String: Any]] {
                ids.append(contentsOf: messages.compactMap { $0["id"] as? String })
            }
            pageToken = json["nextPageToken"] as? String
            pages += 1
        } while pageToken != nil && pages < 5   // safety cap: up to 500 messages

        return ids
    }

    struct FetchedMessage {
        let body: String
        let date: Date
        /// "Display Name <address>". The most reliable clue to who a receipt
        /// is from — the body mentions other brands far too freely.
        let sender: String
        let subject: String
    }

    /// Returns the plain-text body, received date, sender and subject.
    private func fetchMessage(id: String) async throws -> FetchedMessage {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full")!
        let json = try await authorizedGET(url)

        let epochMs = Double(json["internalDate"] as? String ?? "") ?? 0
        let date = Date(timeIntervalSince1970: epochMs / 1000)

        let payload = json["payload"] as? [String: Any]
        let headers = payload?["headers"] as? [[String: Any]] ?? []
        func header(_ name: String) -> String {
            headers.first { ($0["name"] as? String)?.lowercased() == name }?["value"] as? String ?? ""
        }

        return FetchedMessage(body: Self.extractBody(from: payload), date: date,
                              sender: header("from"), subject: header("subject"))
    }

    private func authorizedGET(_ url: URL) async throws -> [String: Any] {
        try await ensureAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GmailSyncError.network("No response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GmailSyncError.network("HTTP \(http.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GmailSyncError.network("Malformed Gmail response")
        }
        return json
    }

    // MARK: - Body extraction (walks the MIME tree)

    private static func extractBody(from payload: [String: Any]?) -> String {
        guard let payload = payload else { return "" }

        // Prefer text/plain, then fall back to text/html (stripped).
        if let plain = findPart(payload, mime: "text/plain") { return plain }
        if let html  = findPart(payload, mime: "text/html")  { return stripHTML(html) }

        // Single-part message with the body at the top level.
        if let bodyData = (payload["body"] as? [String: Any])?["data"] as? String {
            return decodeBase64URL(bodyData)
        }
        return ""
    }

    private static func findPart(_ part: [String: Any], mime: String) -> String? {
        if (part["mimeType"] as? String) == mime,
           let data = (part["body"] as? [String: Any])?["data"] as? String {
            return decodeBase64URL(data)
        }
        if let parts = part["parts"] as? [[String: Any]] {
            for sub in parts {
                if let found = findPart(sub, mime: mime) { return found }
            }
        }
        return nil
    }

    private static func decodeBase64URL(_ str: String) -> String {
        var s = str.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        guard let data = Data(base64Encoded: s) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func stripHTML(_ html: String) -> String {
        // Convert structural tags to newlines BEFORE stripping, so each
        // "Label : value" line of the bank email stays on its own line —
        // the parser's line-bounded regexes depend on this.
        var s = html.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</(?:p|div|tr|li|table|h[1-6])>", with: "\n", options: .regularExpression)
        let noTags = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return noTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .decodingNumericEntities()
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s*\\n\\s*", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - PKCE helpers

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }

    /// Decodes the "email" claim from a Google ID token (JWT).
    private static func email(fromIDToken token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return nil }
        let payload = decodeBase64URL(parts[1])
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["email"] as? String
    }
}

// MARK: - Presentation context for ASWebAuthenticationSession
extension GmailSyncService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            return windowScene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Helpers
private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension CharacterSet {
    /// URL query value allowed set (excludes reserved sub-delims used as separators).
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "+&=")
        return set
    }()
}


private extension String {
    /// Decodes "&#8377;" and "&#x20B9;" style entities. Receipts commonly
    /// encode the currency sign this way, and without decoding the amount has
    /// no currency in front of it and can't be read.
    func decodingNumericEntities() -> String {
        guard contains("&#") else { return self }
        let pattern = #"&#(x[0-9a-fA-F]+|[0-9]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let ns = self as NSString
        var result = ""
        var cursor = 0
        for m in regex.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            let token = ns.substring(with: m.range(at: 1))
            let value = token.hasPrefix("x") || token.hasPrefix("X")
                ? UInt32(token.dropFirst(), radix: 16)
                : UInt32(token, radix: 10)
            if let v = value, let scalar = Unicode.Scalar(v) {
                result.unicodeScalars.append(scalar)
            } else {
                result += ns.substring(with: m.range)
            }
            cursor = m.range.location + m.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
