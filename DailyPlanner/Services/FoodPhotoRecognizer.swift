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

    var isConfident: Bool { confidence >= 0.35 }
}

enum FoodPhotoRecognizer {

    /// Classifies the image and resolves the most likely food.
    /// Calls back on the main thread. `nil` = nothing food-like found.
    static func detectFood(in image: UIImage,
                           completion: @escaping (FoodDetection?) -> Void) {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                let observations = (request.results ?? [])
                    .filter { $0.confidence > 0.03 }
                    .sorted { $0.confidence > $1.confidence }

                var resolved: [(name: String, raw: String, conf: Float)] = []
                for obs in observations.prefix(40) {
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

                let alts = resolved.dropFirst().prefix(4).map(\.name)
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
        "seafood", "dairy", "dessert", "snack", "baked goods", "bread"
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
        "grapes": "grapes", "grape": "grapes",
        "strawberries": "strawberry", "blueberries": "blueberry",
        "pomegranates": "pomegranate", "pineapples": "pineapple",
        "date fruit": "dates", "dried date": "dates",

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
        "beans": "beans", "lentil": "lentils", "chickpea": "chickpeas",
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
        for word in label.split(separator: " ").map(String.init) {
            if ignoredLabels.contains(word) { continue }
            if let mapped = synonyms[word] { return mapped }
        }

        // Last resort: does our calorie DB recognise this label at all?
        if case .unknown = CalorieEstimator.shared.estimate(for: label) {
            return nil
        }
        return label
    }
}
