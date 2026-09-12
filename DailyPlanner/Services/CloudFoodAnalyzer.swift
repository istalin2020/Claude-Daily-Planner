import Foundation
import UIKit

// MARK: - Result models
//
// These mirror the JSON the Cloudflare Worker returns. The Worker already
// normalises every field, so nothing here needs to be optional.

struct CloudFoodItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let portion: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let iron: Double

    private enum CodingKeys: String, CodingKey {
        case name, portion, calories, protein, carbs, fat, fiber, iron
    }
}

struct CloudFoodOption: Identifiable, Codable, Equatable {
    var id = UUID()
    let label: String
    let detail: String

    private enum CodingKeys: String, CodingKey { case label, detail }
}

struct CloudFoodQuestion: Identifiable, Codable, Equatable {
    var id = UUID()
    let questionID: String
    let prompt: String
    let allowCustom: Bool
    let options: [CloudFoodOption]

    private enum CodingKeys: String, CodingKey {
        case questionID = "id"
        case prompt, allowCustom, options
    }
}

struct CloudFoodAnalysis: Codable, Equatable {
    let recognized: Bool
    let dishName: String
    let confidence: Double
    let summary: String
    let items: [CloudFoodItem]
    let questions: [CloudFoodQuestion]
    let notes: String

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var totalProtein : Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs   : Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat     : Double { items.reduce(0) { $0 + $1.fat } }
    var totalFiber   : Double { items.reduce(0) { $0 + $1.fiber } }
    var totalIron    : Double { items.reduce(0) { $0 + $1.iron } }

    /// True when the user should answer something before the numbers are final.
    var needsAnswers: Bool { !questions.isEmpty }
}

/// One answered follow-up, sent back for the final pass.
struct CloudFoodAnswer: Codable, Equatable {
    let prompt: String
    let answer: String
}

// MARK: - Errors

enum CloudFoodError: LocalizedError {
    case notConfigured
    case offline
    case unauthorized
    case dailyLimitReached(String)
    case service(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Smart analysis isn't set up in this build yet."
        case .offline:
            return "No internet connection — using on-device recognition instead."
        case .unauthorized:
            return "This build can't reach the analysis service. Please update the app."
        case .dailyLimitReached(let message):
            return message
        case .service(let message):
            return message
        }
    }
}

// MARK: - Analyzer

/// Sends a food photo to the Daily Planner Worker, which forwards it to OpenAI
/// and returns the dish, portion and nutrition.
///
/// The OpenAI key is never in this app — it lives as a Cloudflare secret. The
/// token below only proves the request came from Daily Planner; it can be
/// rotated from the Worker without shipping a new build (older builds then fall
/// back to on-device recognition, which is the free-tier experience anyway).
enum CloudFoodAnalyzer {

    // ── Configuration ──────────────────────────────────────────────────────
    //
    // Two sources, checked in this order:
    //
    //  1. Values entered in Settings → Analysis Service, stored on the device.
    //     DEBUG builds only. These live outside the repo, so pulling new code
    //     never wipes them — which it does to anything edited in this file.
    //  2. The bundled constants below, which is what App Store users get.
    //
    // For day-to-day testing use (1). Fill in (2) once, at release time.

    /// Worker URL, no trailing slash — e.g. "https://dailyplanner-food.<you>.workers.dev"
    private static let bundledWorkerBaseURL = "https://PASTE-YOUR-WORKER-URL-HERE.workers.dev"

    /// Must match the APP_TOKEN secret set on the Worker.
    private static let bundledAppToken = "PASTE-YOUR-APP-TOKEN-HERE"

    private static let urlOverrideKey   = "dailyplanner_food_service_url"
    private static let tokenOverrideKey = "dailyplanner_food_service_token"

    static var workerBaseURL: String {
        #if DEBUG
        if let stored = UserDefaults.standard.string(forKey: urlOverrideKey),
           !stored.isEmpty {
            // Tolerate a pasted trailing slash rather than failing obscurely.
            return stored.hasSuffix("/") ? String(stored.dropLast()) : stored
        }
        #endif
        return bundledWorkerBaseURL
    }

    static var appToken: String {
        #if DEBUG
        if let stored = UserDefaults.standard.string(forKey: tokenOverrideKey),
           !stored.isEmpty {
            return stored
        }
        #endif
        return bundledAppToken
    }

    /// False until a URL and token are available from either source, so the app
    /// quietly stays on the on-device path instead of firing doomed requests.
    static var isConfigured: Bool {
        !workerBaseURL.contains("PASTE-YOUR")
            && !appToken.contains("PASTE-YOUR")
            && URL(string: workerBaseURL) != nil
    }

    #if DEBUG
    /// True when the device-stored values are in use rather than the bundled
    /// constants — shown in Settings so it's obvious which is active.
    static var usingStoredOverrides: Bool {
        let url = UserDefaults.standard.string(forKey: urlOverrideKey) ?? ""
        let token = UserDefaults.standard.string(forKey: tokenOverrideKey) ?? ""
        return !url.isEmpty && !token.isEmpty
    }

    static func saveOverrides(url: String, token: String) {
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cleanURL, forKey: urlOverrideKey)
        UserDefaults.standard.set(cleanToken, forKey: tokenOverrideKey)
    }

    static func clearOverrides() {
        UserDefaults.standard.removeObject(forKey: urlOverrideKey)
        UserDefaults.standard.removeObject(forKey: tokenOverrideKey)
    }

    /// What's currently stored, so Settings can pre-fill the fields.
    static var storedOverrides: (url: String, token: String) {
        (UserDefaults.standard.string(forKey: urlOverrideKey) ?? "",
         UserDefaults.standard.string(forKey: tokenOverrideKey) ?? "")
    }
    #endif

    /// Longest edge sent to the model. 768px is the sweet spot: enough detail to
    /// tell a papaya from a melon, small enough to stay fast and cheap.
    private static let maxEdge: CGFloat = 768
    private static let jpegQuality: CGFloat = 0.6

    /// Anonymous per-install id used only for the Worker's daily rate limit.
    /// Not tied to the user's identity and never leaves the Worker.
    private static var deviceID: String {
        let key = "dailyplanner_food_device_id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    // ── Public API ─────────────────────────────────────────────────────────

    /// Analyses a photo. Pass `answers` on the second call to fold the user's
    /// replies into the final numbers.
    static func analyze(image: UIImage,
                        mealName: String,
                        answers: [CloudFoodAnswer] = [],
                        note: String = "",
                        completion: @escaping (Result<CloudFoodAnalysis, Error>) -> Void) {

        guard let jpeg = downscaledJPEG(from: image) else {
            DispatchQueue.main.async {
                completion(.failure(CloudFoodError.service("Couldn't prepare that photo.")))
            }
            return
        }

        send(extra: ["image": jpeg.base64EncodedString(), "mimeType": "image/jpeg"],
             mealName: mealName, answers: answers, note: note, completion: completion)
    }

    /// Analyses a dish the user typed, with no photo. Same result shape as the
    /// photo path, so both feed one result screen.
    static func analyze(dishName: String,
                        mealName: String,
                        answers: [CloudFoodAnswer] = [],
                        note: String = "",
                        completion: @escaping (Result<CloudFoodAnalysis, Error>) -> Void) {

        let trimmed = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(CloudFoodError.service("Type a dish name first.")))
            }
            return
        }

        send(extra: ["dishName": trimmed],
             mealName: mealName, answers: answers, note: note, completion: completion)
    }

    // ── Health check ───────────────────────────────────────────────────────

    /// What the Worker reports about itself. `configured` false means the
    /// Worker is deployed but one of its secrets is missing.
    struct Health {
        let configured: Bool
        let model: String
    }

    /// Hits the Worker's `/health` endpoint so Settings can tell the user
    /// exactly what's wrong instead of leaving them guessing.
    static func checkHealth(completion: @escaping (Result<Health, Error>) -> Void) {
        guard isConfigured, let url = URL(string: workerBaseURL + "/health") else {
            DispatchQueue.main.async { completion(.failure(CloudFoodError.notConfigured)) }
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            let finish: (Result<Health, Error>) -> Void = { result in
                DispatchQueue.main.async { completion(result) }
            }

            if error != nil {
                finish(.failure(CloudFoodError.service(
                    "Couldn't reach the service. Check the Worker URL and your connection.")))
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let data = data else {
                finish(.failure(CloudFoodError.service(
                    "The service answered with an error (HTTP \(status)). Check the Worker URL.")))
                return
            }

            struct Payload: Decodable {
                let ok: Bool
                let configured: Bool
                let model: String
            }
            guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                finish(.failure(CloudFoodError.service(
                    "That URL answered, but it isn't the Daily Planner service.")))
                return
            }

            finish(.success(Health(configured: payload.configured, model: payload.model)))
        }.resume()
    }

    // ── Shared request path ────────────────────────────────────────────────

    /// `extra` carries whatever identifies the meal — the photo or the typed
    /// name. Everything else about the request is identical either way.
    private static func send(extra: [String: Any],
                             mealName: String,
                             answers: [CloudFoodAnswer],
                             note: String,
                             completion: @escaping (Result<CloudFoodAnalysis, Error>) -> Void) {

        guard isConfigured, let url = URL(string: workerBaseURL + "/analyze") else {
            DispatchQueue.main.async { completion(.failure(CloudFoodError.notConfigured)) }
            return
        }

        var payload: [String: Any] = ["mealName": mealName, "deviceID": deviceID]
        payload.merge(extra) { _, new in new }

        if !answers.isEmpty {
            payload["answers"] = answers.map { ["prompt": $0.prompt, "answer": $0.answer] }
        }
        if !note.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["note"] = note
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        request.timeoutInterval = 45
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            let finish: (Result<CloudFoodAnalysis, Error>) -> Void = { result in
                DispatchQueue.main.async { completion(result) }
            }

            if let error = error as NSError?,
               error.domain == NSURLErrorDomain,
               [NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut].contains(error.code) {
                finish(.failure(CloudFoodError.offline))
                return
            }
            if let error = error {
                finish(.failure(CloudFoodError.service(error.localizedDescription)))
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data else {
                finish(.failure(CloudFoodError.service("The analysis service returned nothing.")))
                return
            }

            guard (200..<300).contains(status) else {
                finish(.failure(mapError(status: status, data: data)))
                return
            }

            do {
                finish(.success(try JSONDecoder().decode(CloudFoodAnalysis.self, from: data)))
            } catch {
                finish(.failure(CloudFoodError.service("Couldn't read the analysis result.")))
            }
        }.resume()
    }

    // ── Internals ──────────────────────────────────────────────────────────

    private static func mapError(status: Int, data: Data) -> Error {
        struct Envelope: Decodable {
            struct Payload: Decodable { let code: String; let message: String }
            let error: Payload
        }

        let decoded = try? JSONDecoder().decode(Envelope.self, from: data)
        let message = decoded?.error.message ?? "Couldn't analyse that photo. Please try again."

        switch decoded?.error.code {
        case "unauthorized":         return CloudFoodError.unauthorized
        case "not_configured":       return CloudFoodError.notConfigured
        case "daily_limit_reached":  return CloudFoodError.dailyLimitReached(message)
        default:
            if status == 401 { return CloudFoodError.unauthorized }
            return CloudFoodError.service(message)
        }
    }

    /// Shrinks the photo so the upload stays small and the model sees a clean,
    /// correctly-oriented image. Camera shots carry EXIF rotation that redrawing
    /// bakes in — without this the model would sometimes see the plate sideways.
    private static func downscaledJPEG(from image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxEdge / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let flattened = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return flattened.jpegData(compressionQuality: jpegQuality)
    }
}
