import UIKit
import Vision

// MARK: - Food Photo Recognizer
//
// Identifies food in a photo entirely ON DEVICE using Apple's Vision
// framework (VNClassifyImageRequest). No API key, no network, no data
// leaves the phone. Apple's classifier knows ~1300 everyday categories,
// including many foods and ingredients.
//
// The raw Vision labels are then mapped onto our calorie database so a
// detected "orange" becomes a named food with calories attached. Complex
// composed dishes (biryani, shawarma…) are harder for the generic
// classifier, so the caller falls back to asking the user when the
// confidence is low.

struct FoodDetection {
    /// Best food name we could resolve, ready for the calorie estimator.
    let foodName: String
    /// The raw Vision label that produced it (for transparency).
    let rawLabel: String
    /// 0…1 confidence from Vision.
    let confidence: Float
    /// Other plausible foods the user can switch to.
    let alternatives: [String]
    /// True when the name came from text on a package or price label, which
    /// is far more reliable than the generic image classifier.
    let fromLabelText: Bool

    init(foodName: String, rawLabel: String, confidence: Float,
         alternatives: [String], fromLabelText: Bool = false) {
        self.foodName = foodName
        self.rawLabel = rawLabel
        self.confidence = confidence
        self.alternatives = alternatives
        self.fromLabelText = fromLabelText
    }

    /// Only claim a confident identification when the classifier is actually
    /// sure, or the name was read straight off a label.
    var isConfident: Bool { fromLabelText || confidence >= 0.35 }
}

enum FoodPhotoRecognizer {

    /// Classifies the image and resolves the most likely food.
    /// Calls back on the main thread. `nil` = nothing food-like found.
    ///
    /// Two independent signals are used, best-first:
    ///   1. TEXT on the item — packaging, price stickers, menu boards. Read
    ///      with on-device OCR and matched against the food database. When a
    ///      food name is printed, this is far more accurate than guessing
    ///      from pixels.
    ///   2. IMAGE classification via VNClassifyImageRequest.
    static func detectFood(in image: UIImage,
                           completion: @escaping (FoodDetection?) -> Void) {
        // Text needs more detail than classification, so keep a larger copy
        // for OCR and a small one for the classifier.
        let forText  = downscaled(image, maxDimension: 1400)
        let forClass = downscaled(image, maxDimension: 640)

        guard let textCG = forText.cgImage, let classCG = forClass.cgImage else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // ── 1. Read any printed text and look for a food name ──────────
            if let fromText = foodFromLabelText(in: textCG) {
                DispatchQueue.main.async { completion(fromText) }
                return
            }

            // ── 2. Fall back to image classification ───────────────────────
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: classCG, orientation: .up, options: [:])
            do {
                try handler.perform([request])
                let observations = (request.results ?? [])
                    .filter { $0.confidence > 0.01 }
                    .sorted { $0.confidence > $1.confidence }

                var resolved: [(name: String, raw: String, conf: Float)] = []
                for obs in observations.prefix(80) {
                    let label = obs.identifier.lowercased()
                        .replacingOccurrences(of: "_", with: " ")
                    if let food = resolveFood(from: label) {
                        // Keep the highest-confidence hit per food name.
                        if !resolved.contains(where: { $0.name == food }) {
                            resolved.append((food, label, obs.confidence))
                        }
                    }
                }

                guard let best = resolved.first else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                // Offer more alternatives when the top guess is weak.
                let altCount = best.conf < 0.35 ? 6 : 4
                let alts = resolved.dropFirst().prefix(altCount).map(\.name)
                let detection = FoodDetection(foodName: best.name,
                                              rawLabel: best.raw,
                                              confidence: best.conf,
                                              alternatives: Array(alts))
                DispatchQueue.main.async { completion(detection) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - Reading food names off packaging / price labels

    /// Runs on-device OCR and returns the first food name found in the text.
    /// Grocery stickers, wrappers and menu boards usually spell out exactly
    /// what the item is, so this beats guessing from the picture.
    private static func foodFromLabelText(in cgImage: CGImage) -> FoodDetection? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results, !observations.isEmpty else { return nil }

        // Longest, most confident lines first — a product name is usually the
        // most prominent text, while codes and prices are short.
        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }

        var matches: [String] = []
        for line in lines {
            let lower = line.lowercased()
            // Skip lines that are mostly digits (prices, barcodes, dates).
            let digits = lower.filter(\.isNumber).count
            if digits * 2 > lower.count { continue }

            for word in tokenize(lower) where word.count >= 3 {
                if let food = resolveFood(from: word), !matches.contains(food) {
                    matches.append(food)
                }
            }
            // Also try the whole line ("dragon fruit", "sweet potato").
            if let food = resolveFood(from: lower), !matches.contains(food) {
                matches.insert(food, at: 0)
            }
        }

        guard let best = matches.first else { return nil }
        return FoodDetection(foodName: best,
                             rawLabel: "label text",
                             confidence: 0.9,
                             alternatives: Array(matches.dropFirst().prefix(5)),
                             fromLabelText: true)
    }

    /// Splits a line into comparable words, dropping punctuation.
    private static func tokenize(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Redraws the image at a smaller size with orientation baked in.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0 else { return image }

        let scale = min(1, maxDimension / max(w, h))
        let target = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // MARK: - Label → food resolution

    /// Vision labels that aren't foods themselves — ignore them so a photo
    /// of a plate doesn't get logged as "plate".
    private static let ignoredLabels: Set<String> = [
        "food", "cuisine", "dish", "meal", "produce", "plant", "plate",
        "bowl", "cup", "glass", "table", "tableware", "cutlery", "kitchen",
        "restaurant", "indoor", "outdoor", "still life", "close up",
        "material", "texture", "pattern", "person", "hand", "furniture",
        "container", "packaged goods", "drink", "beverage", "fruit",
        "vegetable", "citrus", "berry", "nut", "seed", "grain", "meat",
        "seafood", "dairy", "dessert", "snack", "baked goods", "bread",
        // Plurals and packaging words that show up in OCR'd price stickers
        "fruits", "vegetables", "veggies", "berries", "nuts", "seeds",
        "grains", "meats", "drinks", "beverages", "desserts", "snacks",
        "groceries", "grocery", "organic", "fresh", "produce section",
        "price", "total", "weight", "net", "packed", "expiry", "best before",
        "thank you", "daily", "store", "market", "supermarket", "hypermarket"
    ]

    /// Maps Vision's vocabulary onto names our calorie database knows.
    /// Left side = what Vision may report, right side = our food name.
    private static let synonyms: [String: String] = [
        // Fruits
        "mandarin orange": "orange", "tangerine": "orange", "clementine": "orange",
        "navel orange": "orange", "satsuma": "orange",
        "granny smith": "apple", "red delicious": "apple",
        "plantain": "banana",
        "watermelon": "watermelon", "muskmelon": "melon", "cantaloupe": "melon",
        "honeydew": "melon", "melon": "melon",
        "grapes": "grapes", "grape": "grapes",
        "strawberries": "strawberry", "blueberries": "blueberry",
        "pomegranates": "pomegranate", "pineapples": "pineapple",
        "date fruit": "dates", "dried date": "dates",

        // Tropical & other produce the generic classifier often mislabels
        "papaya": "papaya", "papayas": "papaya", "pawpaw": "papaya",
        "guava": "guava", "guavas": "guava",
        "lychee": "lychee", "litchi": "lychee",
        "jackfruit": "jackfruit", "dragon fruit": "dragon fruit",
        "pitaya": "dragon fruit", "passion fruit": "passion fruit",
        "starfruit": "starfruit", "carambola": "starfruit",
        "custard apple": "custard apple", "sapota": "chikoo", "chikoo": "chikoo",
        "fig": "fig", "figs": "fig", "apricot": "apricot", "plum": "plum",
        "raspberry": "raspberry", "raspberries": "raspberry",
        "blackberry": "blackberry", "blackberries": "blackberry",
        "cranberry": "cranberry", "cranberries": "cranberry",
        "mulberry": "mulberry", "gooseberry": "gooseberry", "amla": "gooseberry",
        "grapefruit": "grapefruit", "raisin": "raisin", "raisins": "raisin",
        "coconut": "coconut", "kiwi": "kiwi", "kiwifruit": "kiwi",
        "lemon": "lemon", "lime": "lemon", "cherry": "cherry", "cherries": "cherry",
        "pear": "pear", "pears": "pear", "peach": "peach", "peaches": "peach",

        // Vegetables
        "cauliflower": "cauliflower", "cabbage": "cabbage",
        "eggplant": "brinjal", "aubergine": "brinjal", "brinjal": "brinjal",
        "okra": "okra", "pumpkin": "pumpkin", "squash": "pumpkin",
        "zucchini": "zucchini", "courgette": "zucchini",
        "bell pepper": "capsicum", "capsicum": "capsicum",
        "chili": "chilli", "chilli": "chilli", "chili pepper": "chilli",
        "radish": "radish", "turnip": "turnip", "beetroot": "beetroot",
        "ginger": "ginger", "garlic": "garlic", "celery": "celery",
        "asparagus": "asparagus", "kale": "kale", "cucumber": "cucumber",
        "green beans": "green beans", "cauliflower head": "cauliflower",
        "yam": "yam", "taro": "yam", "gourd": "bottle gourd",

        // Nuts & seeds
        "hazelnut": "hazelnut", "pecan": "pecan", "macadamia": "macadamia",
        "sunflower seed": "sunflower seed", "pumpkin seed": "pumpkin seed",
        "chia": "chia seed", "flaxseed": "flax seed", "sesame": "sesame seed",

        // Common plates the classifier does recognise
        "pizza": "pizza", "hamburger": "burger", "cheeseburger": "burger",
        "french fries": "french fries", "fries": "french fries",
        "hot dog": "hot dog", "sandwich": "sandwich", "burrito": "burrito",
        "taco": "taco", "sushi": "sushi", "salad": "salad",
        "soup": "soup", "stew": "curry", "noodle": "noodles",
        "pasta": "pasta", "spaghetti": "pasta", "macaroni": "pasta",
        "rice": "rice", "fried rice": "fried rice",
        "omelette": "omelette", "omelet": "omelette",
        "fried egg": "egg", "boiled egg": "egg", "scrambled eggs": "egg",
        "pancake": "pancake", "waffle": "waffle", "toast": "toast",
        "croissant": "croissant", "bagel": "bagel", "muffin": "muffin",
        "doughnut": "donut", "donut": "donut",
        "cake": "cake", "cupcake": "cake", "cheesecake": "cheesecake",
        "cookie": "cookie", "biscuit": "cookie", "brownie": "brownie",
        "ice cream": "ice cream", "chocolate": "chocolate",
        "popcorn": "popcorn", "pretzel": "pretzel",
        "cereal": "cereal", "oatmeal": "oatmeal", "porridge": "oatmeal",
        "yoghurt": "yogurt", "yogurt": "yogurt", "cheese": "cheese",
        "milk": "milk", "coffee": "coffee", "tea": "tea",
        "juice": "juice", "smoothie": "smoothie", "soda": "soda",
        "beer": "beer", "wine": "wine",
        "steak": "steak", "roast beef": "beef", "beef": "beef",
        "chicken": "chicken", "fried chicken": "fried chicken",
        "grilled chicken": "grilled chicken",
        "fish": "fish", "salmon": "salmon", "tuna": "tuna",
        "shrimp": "shrimp", "prawn": "shrimp", "crab": "crab",
        "bacon": "bacon", "sausage": "sausage", "ham": "ham",
        "potato": "potato", "mashed potato": "mashed potatoes",
        "sweet potato": "sweet potato", "corn": "corn",
        "tomato": "tomato", "carrot": "carrot", "broccoli": "broccoli",
        "cucumber": "cucumber", "lettuce": "salad", "spinach": "spinach",
        "onion": "onion", "garlic": "garlic", "mushroom": "mushroom",
        "avocado": "avocado", "olive": "olives", "olives": "olives",
        // Pulses, legumes & sprouts
        "beans": "beans", "bean": "beans", "green bean": "beans",
        "kidney bean": "kidney beans", "black bean": "black beans",
        "baked beans": "beans", "broad bean": "beans", "lima bean": "beans",
        "lentil": "lentils", "lentils": "lentils", "dal": "dal", "daal": "dal",
        "pulse": "pulses", "pulses": "pulses", "legume": "pulses",
        "chickpea": "chickpeas", "chickpeas": "chickpeas", "garbanzo": "chickpeas",
        "sprout": "sprouts", "sprouts": "sprouts", "bean sprout": "sprouts",
        "bean sprouts": "sprouts", "sprouted": "sprouts",
        "mung bean": "moong", "mung": "moong", "moong": "moong",
        "soybean": "soybean", "soy": "soybean", "edamame": "soybean",
        "tofu": "tofu", "green pea": "pea", "peas": "pea", "split pea": "pulses",
        "peanut": "peanuts", "almond": "almonds", "cashew": "cashews",
        "walnut": "walnuts", "pistachio": "pistachios",

        // Oils & fats
        "cooking oil": "cooking oil", "vegetable oil": "cooking oil",
        "sunflower oil": "sunflower oil", "coconut oil": "coconut oil",
        "sesame oil": "sesame oil", "mustard oil": "mustard oil",
        "ghee": "ghee", "clarified butter": "ghee", "butter": "butter",

        // Indian
        "naan": "naan", "chapati": "roti", "roti": "roti",
        "papad": "appalam", "papadum": "appalam", "poppadom": "appalam",
        "appalam": "appalam", "flatbread": "roti", "tortilla": "roti",
        "paratha": "paratha", "dosa": "dosa", "idli": "idli",
        "samosa": "samosa", "pakora": "pakora", "biryani": "biryani",
        "curry": "curry", "dal": "dal", "paneer": "paneer",
        "tandoori chicken": "tandoori chicken", "butter chicken": "butter chicken",
        "chutney": "chutney", "raita": "raita", "lassi": "lassi",
        "gulab jamun": "gulab jamun", "jalebi": "jalebi", "laddu": "laddu",

        // Mediterranean / Middle-Eastern
        "hummus": "hummus", "falafel": "falafel", "shawarma": "shawarma",
        "kebab": "kebab", "gyro": "shawarma", "pita": "pita",
        "tabbouleh": "tabbouleh", "baklava": "baklava",
        "couscous": "couscous", "halloumi": "halloumi", "feta": "feta"
    ]

    /// Tries the synonym map first, then falls back to matching the label
    /// against the calorie database's own keywords.
    private static func resolveFood(from label: String) -> String? {
        guard !ignoredLabels.contains(label) else { return nil }

        if let mapped = synonyms[label] { return mapped }

        // Multi-word labels: check each word (e.g. "orange juice glass").
        let words = label.split(separator: " ").map(String.init)
        for word in words {
            if ignoredLabels.contains(word) { continue }
            if let mapped = synonyms[word] { return mapped }
        }

        // Try adjacent word pairs ("bean sprouts" inside "fresh bean sprouts").
        if words.count > 1 {
            for i in 0..<(words.count - 1) {
                let pair = "\(words[i]) \(words[i + 1])"
                if let mapped = synonyms[pair] { return mapped }
            }
        }

        // Does our calorie DB recognise the whole label?
        if case .unknown = CalorieEstimator.shared.estimate(for: label) {
            // Finally, try individual words against the DB so a label like
            // "sprouted mung salad" still resolves via "sprouted".
            for word in words where word.count > 3 && !ignoredLabels.contains(word) {
                if case .unknown = CalorieEstimator.shared.estimate(for: word) { continue }
                return word
            }
            return nil
        }
        return label
    }
}
