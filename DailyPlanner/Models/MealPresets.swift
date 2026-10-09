import Foundation

// MARK: - Ready-made dishes
//
// Pre-calculated dishes for the "Choose" picker on each meal, grouped by
// cuisine. Figures are for one unit (a piece, a bowl, a plate…) of a typical
// home or restaurant serving, from standard nutrition tables (IFCT 2017 for
// Indian dishes, USDA FoodData Central and UK CoFID for the rest), rounded.
// They're a good everyday guide, not lab values.

enum MealCuisine: String, CaseIterable, Identifiable {
    case southIndian   = "South Indian"
    case northIndian   = "North Indian"
    case english       = "English"
    case american      = "American"
    case mediterranean = "Mediterranean"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .southIndian:   return "🥥"
        case .northIndian:   return "🫓"
        case .english:       return "🫖"
        case .american:      return "🥞"
        case .mediterranean: return "🫒"
        }
    }
}

struct MealPreset: Identifiable, Hashable {
    let name: String
    /// What one unit is: "piece", "bowl", "plate", "cup"…
    let unit: String
    /// How many units the picker starts at — 3 idli, 1 plate of biryani.
    let defaultQuantity: Int
    /// Per unit.
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let iron: Double
    /// What the unit holds, e.g. "150 ml" — shown under the name.
    var detail: String = ""

    var id: String { name + "|" + unit }

    /// "3 pieces", "1 bowl (150 ml)"
    func portion(_ quantity: Int) -> String {
        let unitText = quantity == 1 ? unit : MealPreset.plural(unit)
        let base = "\(quantity) \(unitText)"
        return detail.isEmpty ? base : "\(base) · \(detail)"
    }

    func item(quantity: Int) -> MealItem {
        let q = Double(quantity)
        return MealItem(name: name,
                        calories: Int((calories * q).rounded()),
                        portion: portion(quantity),
                        protein: (protein * q * 10).rounded() / 10,
                        fiber: (fiber * q * 10).rounded() / 10,
                        iron: (iron * q * 10).rounded() / 10)
    }

    static func plural(_ unit: String) -> String {
        switch unit {
        case "glass":   return "glasses"
        case "dish":    return "dishes"
        case "handful": return "handfuls"
        case "slice":   return "slices"
        case "serving": return "servings"
        default:        return unit.hasSuffix("s") ? unit : unit + "s"
        }
    }
}

enum MealPresetLibrary {

    /// The dishes for one meal ("breakfast", "lunch", "dinner", "snacks").
    static func presets(for meal: String, cuisine: MealCuisine) -> [MealPreset] {
        table[cuisine]?[meal] ?? []
    }

    /// Every dish for a meal across all cuisines, for searching.
    static func allPresets(for meal: String) -> [(MealCuisine, MealPreset)] {
        MealCuisine.allCases.flatMap { c in presets(for: meal, cuisine: c).map { (c, $0) } }
    }

    /// The best ready-made dish for something typed — "dosa" → Plain Dosa —
    /// so the on-device search answers instantly with real figures. Exact
    /// names first, then a dish whose name contains every typed word.
    static func match(_ text: String) -> MealPreset? {
        let typed = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard typed.count >= 3 else { return nil }
        let all = table.values.flatMap { $0.values.flatMap { $0 } }
        if let exact = all.first(where: { $0.name.lowercased() == typed }) { return exact }
        // The typed words must name the whole dish, apart from words like
        // "plain": "dosa" is Plain Dosa, but "egg" is not Egg Curry — that
        // goes to the regular estimate, which asks how it was cooked.
        // Words are matched whole, so "tea" never finds "Steamed Rice".
        let filler: Set<String> = ["plain", "steamed", "with", "and", "the", "of"]
        let words = typed.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        // "Roti / Chapati" answers to either name.
        let candidates = all.filter { p in
            p.name.lowercased().components(separatedBy: " / ").contains { alternative in
                let nameWords = alternative
                    .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
                let typedCovered = words.allSatisfy { w in nameWords.contains { $0.hasPrefix(w) } }
                let nameCovered = nameWords.allSatisfy { n in
                    filler.contains(n) || words.contains { n.hasPrefix($0) }
                }
                return typedCovered && nameCovered
            }
        }
        // The plain version first ("Dosa" → Plain Dosa, "rice" → Steamed
        // Rice), then a dish named after it, then the shortest name.
        func rank(_ p: MealPreset) -> Int {
            let n = p.name.lowercased()
            if n.hasPrefix("plain ") || n.hasPrefix("steamed ") { return 0 }
            if n.hasPrefix(typed) { return 1 }
            return 2
        }
        return candidates.min { a, b in
            rank(a) != rank(b) ? rank(a) < rank(b) : a.name.count < b.name.count
        }
    }

    private static func p(_ name: String, _ unit: String, _ qty: Int, _ cal: Double,
                          p: Double, c: Double, f: Double, fi: Double, fe: Double,
                          _ detail: String = "") -> MealPreset {
        MealPreset(name: name, unit: unit, defaultQuantity: qty, calories: cal,
                   protein: p, carbs: c, fat: f, fiber: fi, iron: fe, detail: detail)
    }

    // MARK: - Table

    private static let table: [MealCuisine: [String: [MealPreset]]] = [

        .southIndian: [
            "breakfast": [
                p("Idli", "piece", 3, 58, p: 2.0, c: 12, f: 0.4, fi: 0.6, fe: 0.4),
                p("Plain Dosa", "piece", 2, 133, p: 3.0, c: 20, f: 4.5, fi: 0.8, fe: 0.7),
                p("Masala Dosa", "piece", 1, 330, p: 6.0, c: 45, f: 14, fi: 3.0, fe: 1.5),
                p("Ven Pongal", "bowl", 1, 320, p: 8.0, c: 45, f: 12, fi: 2.0, fe: 1.4, "200 g"),
                p("Medu Vada", "piece", 2, 97, p: 3.5, c: 9, f: 5.5, fi: 1.2, fe: 0.8),
                p("Rava Upma", "bowl", 1, 250, p: 6.0, c: 38, f: 8, fi: 2.5, fe: 1.2, "200 g"),
                p("Appam", "piece", 2, 120, p: 2.0, c: 24, f: 1.5, fi: 0.5, fe: 0.3),
                p("Sambar", "bowl", 1, 110, p: 5.0, c: 15, f: 3.5, fi: 4.0, fe: 1.5, "150 ml"),
                p("Coconut Chutney", "serving", 1, 70, p: 0.8, c: 2.5, f: 6.5, fi: 1.5, fe: 0.3, "2 tbsp"),
                p("Filter Coffee", "cup", 1, 90, p: 2.5, c: 12, f: 3.5, fi: 0, fe: 0.1, "150 ml"),
            ],
            "lunch": [
                p("South Indian Veg Meals", "plate", 1, 750, p: 20, c: 115, f: 22, fi: 12, fe: 5.0,
                  "rice, sambar, rasam, poriyal, kootu, curd"),
                p("Steamed Rice", "cup", 2, 195, p: 4.0, c: 43, f: 0.4, fi: 0.6, fe: 0.3, "150 g cooked"),
                p("Sambar", "bowl", 1, 110, p: 5.0, c: 15, f: 3.5, fi: 4.0, fe: 1.5, "150 ml"),
                p("Rasam", "bowl", 1, 60, p: 1.5, c: 8, f: 2.5, fi: 1.0, fe: 0.6, "150 ml"),
                p("Curd Rice", "bowl", 1, 280, p: 8.0, c: 42, f: 8, fi: 0.8, fe: 0.4, "250 g"),
                p("Lemon Rice", "bowl", 1, 330, p: 5.0, c: 55, f: 10, fi: 1.5, fe: 1.0, "200 g"),
                p("Vegetable Poriyal", "bowl", 1, 110, p: 3.0, c: 9, f: 7, fi: 3.5, fe: 1.0, "100 g"),
                p("Kootu", "bowl", 1, 150, p: 6.0, c: 18, f: 6, fi: 4.0, fe: 1.5, "150 g"),
                p("Chicken Chettinad", "bowl", 1, 300, p: 25, c: 8, f: 19, fi: 1.5, fe: 1.5, "150 g"),
                p("Kerala Fish Curry", "bowl", 1, 240, p: 22, c: 6, f: 14, fi: 1.0, fe: 1.2, "150 g"),
            ],
            "dinner": [
                p("Plain Dosa", "piece", 2, 133, p: 3.0, c: 20, f: 4.5, fi: 0.8, fe: 0.7),
                p("Idli", "piece", 3, 58, p: 2.0, c: 12, f: 0.4, fi: 0.6, fe: 0.4),
                p("Onion Uttapam", "piece", 1, 210, p: 5.0, c: 32, f: 6.5, fi: 2.0, fe: 1.0),
                p("Rava Dosa", "piece", 1, 160, p: 3.0, c: 24, f: 6, fi: 0.8, fe: 0.6),
                p("Idiyappam", "piece", 3, 60, p: 1.0, c: 13, f: 0.2, fi: 0.4, fe: 0.2),
                p("Kerala Parotta", "piece", 2, 300, p: 6.0, c: 40, f: 13, fi: 1.5, fe: 1.2),
                p("Kothu Parotta", "plate", 1, 550, p: 15, c: 60, f: 28, fi: 3.0, fe: 2.5),
                p("Egg Curry", "bowl", 1, 260, p: 14, c: 8, f: 19, fi: 1.5, fe: 2.0, "2 eggs"),
                p("Chicken Biryani", "plate", 1, 550, p: 25, c: 65, f: 20, fi: 2.0, fe: 2.0, "300 g"),
            ],
            "snacks": [
                p("Valaikkai Bajji", "piece", 3, 75, p: 1.2, c: 8, f: 4.5, fi: 0.8, fe: 0.4),
                p("Masala Vada", "piece", 2, 110, p: 4.5, c: 10, f: 6, fi: 2.0, fe: 1.0),
                p("Chana Sundal", "cup", 1, 160, p: 8.0, c: 22, f: 4.5, fi: 6.0, fe: 2.5, "100 g"),
                p("Murukku", "piece", 2, 130, p: 2.0, c: 15, f: 7, fi: 1.0, fe: 0.6, "25 g"),
                p("Bonda", "piece", 2, 120, p: 2.5, c: 14, f: 6, fi: 1.0, fe: 0.5),
                p("Banana", "piece", 1, 105, p: 1.3, c: 27, f: 0.4, fi: 3.1, fe: 0.3),
                p("Filter Coffee", "cup", 1, 90, p: 2.5, c: 12, f: 3.5, fi: 0, fe: 0.1, "150 ml"),
                p("Tender Coconut Water", "glass", 1, 45, p: 0.5, c: 9, f: 0.5, fi: 0, fe: 0.3, "250 ml"),
            ],
        ],

        .northIndian: [
            "breakfast": [
                p("Aloo Paratha", "piece", 2, 290, p: 6.0, c: 40, f: 12, fi: 4.0, fe: 1.8),
                p("Paneer Paratha", "piece", 1, 320, p: 12, c: 35, f: 15, fi: 3.0, fe: 1.5),
                p("Poha", "bowl", 1, 250, p: 5.0, c: 42, f: 7, fi: 2.0, fe: 2.5, "200 g"),
                p("Besan Chilla", "piece", 2, 120, p: 6.0, c: 14, f: 4.5, fi: 2.5, fe: 1.3),
                p("Chole Bhature", "plate", 1, 650, p: 18, c: 78, f: 30, fi: 10, fe: 4.0, "2 bhature"),
                p("Sweet Lassi", "glass", 1, 220, p: 7.0, c: 32, f: 7, fi: 0, fe: 0.2, "250 ml"),
                p("Masala Chai", "cup", 1, 100, p: 3.0, c: 14, f: 3.5, fi: 0, fe: 0.2, "150 ml"),
            ],
            "lunch": [
                p("North Indian Thali", "plate", 1, 850, p: 25, c: 110, f: 32, fi: 14, fe: 6.0,
                  "roti, rice, dal, sabzi, raita"),
                p("Roti / Chapati", "piece", 3, 105, p: 3.0, c: 18, f: 2.5, fi: 2.5, fe: 1.0),
                p("Dal Tadka", "bowl", 1, 180, p: 9.0, c: 22, f: 6, fi: 5.0, fe: 2.0, "150 g"),
                p("Rajma Chawal", "plate", 1, 450, p: 15, c: 75, f: 9, fi: 12, fe: 4.0),
                p("Paneer Butter Masala", "bowl", 1, 380, p: 14, c: 12, f: 30, fi: 2.0, fe: 1.0, "150 g"),
                p("Chicken Curry", "bowl", 1, 280, p: 24, c: 7, f: 17, fi: 1.5, fe: 1.5, "150 g"),
                p("Mixed Veg Sabzi", "bowl", 1, 150, p: 4.0, c: 14, f: 9, fi: 4.0, fe: 1.2, "150 g"),
                p("Jeera Rice", "cup", 1, 230, p: 4.0, c: 42, f: 5, fi: 0.8, fe: 0.5, "150 g"),
                p("Raita", "bowl", 1, 80, p: 3.5, c: 6, f: 4.5, fi: 0.5, fe: 0.2, "100 g"),
            ],
            "dinner": [
                p("Roti / Chapati", "piece", 3, 105, p: 3.0, c: 18, f: 2.5, fi: 2.5, fe: 1.0),
                p("Butter Naan", "piece", 2, 300, p: 8.0, c: 48, f: 8, fi: 2.0, fe: 2.0),
                p("Dal Makhani", "bowl", 1, 300, p: 11, c: 28, f: 16, fi: 7.0, fe: 2.5, "150 g"),
                p("Palak Paneer", "bowl", 1, 280, p: 14, c: 10, f: 20, fi: 3.5, fe: 3.0, "150 g"),
                p("Butter Chicken", "bowl", 1, 430, p: 28, c: 12, f: 30, fi: 1.5, fe: 1.5, "150 g"),
                p("Veg Pulao", "plate", 1, 350, p: 7.0, c: 60, f: 9, fi: 3.0, fe: 1.5, "250 g"),
                p("Moong Dal Khichdi", "bowl", 1, 280, p: 10, c: 45, f: 6, fi: 4.5, fe: 2.0, "250 g"),
            ],
            "snacks": [
                p("Samosa", "piece", 1, 260, p: 4.5, c: 28, f: 15, fi: 2.5, fe: 1.2),
                p("Onion Pakora", "serving", 1, 200, p: 4.0, c: 20, f: 12, fi: 2.5, fe: 1.0, "4 pieces"),
                p("Pani Puri", "plate", 1, 210, p: 4.0, c: 35, f: 6, fi: 3.0, fe: 1.5, "6 puris"),
                p("Khaman Dhokla", "piece", 3, 65, p: 2.5, c: 10, f: 1.5, fi: 0.8, fe: 0.5),
                p("Roasted Makhana", "cup", 1, 110, p: 3.5, c: 20, f: 1.5, fi: 4.0, fe: 0.5, "30 g"),
                p("Jalebi", "piece", 2, 150, p: 0.8, c: 25, f: 5.5, fi: 0.2, fe: 0.3),
                p("Masala Chai", "cup", 1, 100, p: 3.0, c: 14, f: 3.5, fi: 0, fe: 0.2, "150 ml"),
            ],
        ],

        .english: [
            "breakfast": [
                p("Full English Breakfast", "plate", 1, 800, p: 40, c: 45, f: 50, fi: 6.0, fe: 5.0,
                  "eggs, bacon, sausage, beans, toast"),
                p("Scrambled Eggs", "serving", 1, 200, p: 13, c: 2, f: 15, fi: 0, fe: 1.6, "2 eggs"),
                p("Buttered Toast", "slice", 2, 120, p: 3.0, c: 14, f: 6, fi: 1.0, fe: 0.8),
                p("Baked Beans on Toast", "plate", 1, 330, p: 14, c: 52, f: 6, fi: 9.0, fe: 3.0),
                p("Porridge with Milk", "bowl", 1, 250, p: 10, c: 38, f: 7, fi: 4.0, fe: 1.8),
                p("Bacon Sandwich", "piece", 1, 400, p: 20, c: 35, f: 20, fi: 2.0, fe: 2.0),
                p("Tea with Milk", "cup", 1, 35, p: 1.0, c: 4, f: 1.5, fi: 0, fe: 0),
            ],
            "lunch": [
                p("Fish and Chips", "plate", 1, 850, p: 35, c: 85, f: 40, fi: 7.0, fe: 2.5),
                p("Jacket Potato, Beans & Cheese", "piece", 1, 450, p: 18, c: 65, f: 12, fi: 9.0, fe: 3.0),
                p("Ploughman's Lunch", "plate", 1, 650, p: 25, c: 45, f: 40, fi: 5.0, fe: 2.5),
                p("Chicken & Mushroom Pie", "piece", 1, 520, p: 20, c: 38, f: 32, fi: 2.0, fe: 2.0),
                p("Cheese & Pickle Sandwich", "piece", 1, 420, p: 17, c: 40, f: 21, fi: 3.0, fe: 1.5),
                p("Tomato Soup with Bread", "bowl", 1, 220, p: 6.0, c: 35, f: 6, fi: 3.0, fe: 1.5),
            ],
            "dinner": [
                p("Roast Chicken Dinner", "plate", 1, 700, p: 45, c: 55, f: 30, fi: 7.0, fe: 3.0,
                  "roast potatoes, veg, gravy"),
                p("Shepherd's Pie", "serving", 1, 450, p: 22, c: 35, f: 24, fi: 4.0, fe: 2.5, "300 g"),
                p("Bangers and Mash", "plate", 1, 650, p: 22, c: 50, f: 40, fi: 5.0, fe: 2.5),
                p("Beef Stew", "bowl", 1, 400, p: 30, c: 25, f: 18, fi: 4.0, fe: 3.5),
                p("Grilled Salmon & Vegetables", "plate", 1, 450, p: 35, c: 18, f: 26, fi: 5.0, fe: 1.5),
                p("Toad in the Hole", "serving", 1, 600, p: 20, c: 45, f: 38, fi: 2.0, fe: 2.0),
            ],
            "snacks": [
                p("Scone with Jam & Cream", "piece", 1, 350, p: 5.0, c: 45, f: 17, fi: 1.5, fe: 1.0),
                p("Digestive Biscuit", "piece", 2, 70, p: 1.0, c: 9.5, f: 3, fi: 0.5, fe: 0.4),
                p("Crumpet with Butter", "piece", 1, 140, p: 3.0, c: 20, f: 5, fi: 1.0, fe: 0.6),
                p("Sausage Roll", "piece", 1, 300, p: 8.0, c: 22, f: 20, fi: 1.2, fe: 1.0),
                p("Apple", "piece", 1, 95, p: 0.5, c: 25, f: 0.3, fi: 4.4, fe: 0.2),
                p("Tea with Milk", "cup", 1, 35, p: 1.0, c: 4, f: 1.5, fi: 0, fe: 0),
            ],
        ],

        .american: [
            "breakfast": [
                p("Pancakes with Syrup", "piece", 3, 175, p: 4.0, c: 30, f: 4.5, fi: 0.8, fe: 1.0),
                p("Bacon & Eggs", "plate", 1, 380, p: 24, c: 2, f: 30, fi: 0, fe: 2.0, "2 eggs, 3 strips"),
                p("Bagel with Cream Cheese", "piece", 1, 360, p: 12, c: 55, f: 10, fi: 2.5, fe: 3.5),
                p("Waffle", "piece", 2, 220, p: 6.0, c: 25, f: 11, fi: 0.8, fe: 1.7),
                p("Breakfast Burrito", "piece", 1, 500, p: 25, c: 45, f: 24, fi: 4.0, fe: 3.0),
                p("Cereal with Milk", "bowl", 1, 250, p: 8.0, c: 45, f: 4.5, fi: 3.0, fe: 8.0),
                p("Yogurt Parfait", "cup", 1, 280, p: 15, c: 40, f: 7, fi: 3.0, fe: 1.0),
                p("Coffee with Milk", "cup", 1, 50, p: 2.0, c: 5, f: 2, fi: 0, fe: 0.1),
            ],
            "lunch": [
                p("Cheeseburger", "piece", 1, 550, p: 30, c: 40, f: 30, fi: 2.0, fe: 4.0),
                p("Grilled Chicken Sandwich", "piece", 1, 420, p: 32, c: 40, f: 14, fi: 3.0, fe: 2.5),
                p("Chicken Caesar Salad", "bowl", 1, 450, p: 35, c: 15, f: 28, fi: 3.0, fe: 2.0),
                p("Club Sandwich", "piece", 1, 590, p: 30, c: 45, f: 32, fi: 3.0, fe: 3.0),
                p("Pepperoni Pizza", "slice", 2, 300, p: 13, c: 34, f: 12, fi: 2.0, fe: 2.5),
                p("Mac and Cheese", "cup", 1, 380, p: 15, c: 45, f: 16, fi: 2.0, fe: 1.5),
                p("French Fries", "serving", 1, 365, p: 4.0, c: 48, f: 17, fi: 4.0, fe: 0.8, "medium"),
            ],
            "dinner": [
                p("Steak with Potatoes", "plate", 1, 700, p: 50, c: 40, f: 38, fi: 4.0, fe: 5.0),
                p("BBQ Chicken & Coleslaw", "plate", 1, 600, p: 40, c: 35, f: 32, fi: 4.0, fe: 2.0),
                p("Spaghetti & Meatballs", "plate", 1, 650, p: 30, c: 75, f: 24, fi: 5.0, fe: 4.5),
                p("Fried Chicken", "piece", 2, 275, p: 17.5, c: 10, f: 18, fi: 0.5, fe: 1.0),
                p("Beef Tacos", "piece", 2, 210, p: 10, c: 15, f: 12, fi: 2.0, fe: 1.5),
                p("Chili con Carne", "bowl", 1, 350, p: 25, c: 28, f: 15, fi: 8.0, fe: 4.0),
            ],
            "snacks": [
                p("Chocolate Chip Cookie", "piece", 2, 160, p: 2.0, c: 21, f: 8, fi: 0.8, fe: 0.8),
                p("Butter Popcorn", "serving", 1, 170, p: 3.0, c: 18, f: 10, fi: 3.0, fe: 0.8, "3 cups"),
                p("Peanut Butter Sandwich", "piece", 1, 350, p: 13, c: 35, f: 18, fi: 4.0, fe: 2.0),
                p("Protein Bar", "piece", 1, 220, p: 20, c: 24, f: 7, fi: 4.0, fe: 2.0),
                p("Glazed Donut", "piece", 1, 250, p: 3.5, c: 30, f: 13, fi: 0.8, fe: 1.0),
                p("Banana Smoothie", "glass", 1, 250, p: 7.0, c: 45, f: 4, fi: 4.0, fe: 0.8, "350 ml"),
            ],
        ],

        .mediterranean: [
            "breakfast": [
                p("Shakshuka", "serving", 1, 300, p: 16, c: 15, f: 20, fi: 4.0, fe: 3.0, "2 eggs"),
                p("Greek Yogurt, Honey & Nuts", "bowl", 1, 300, p: 17, c: 28, f: 14, fi: 1.5, fe: 0.8),
                p("Ful Medames with Bread", "plate", 1, 420, p: 20, c: 60, f: 11, fi: 15, fe: 5.0),
                p("Za'atar Manakish", "piece", 1, 380, p: 12, c: 45, f: 17, fi: 3.0, fe: 3.0),
                p("Feta & Olive Omelette", "serving", 1, 320, p: 21, c: 3, f: 25, fi: 0.8, fe: 2.0),
                p("Pita with Hummus", "serving", 1, 330, p: 11, c: 45, f: 12, fi: 7.0, fe: 3.0),
            ],
            "lunch": [
                p("Chicken Shawarma Wrap", "piece", 1, 550, p: 35, c: 50, f: 22, fi: 4.0, fe: 3.0),
                p("Falafel Wrap", "piece", 1, 500, p: 15, c: 60, f: 22, fi: 9.0, fe: 4.0),
                p("Chicken Souvlaki Plate", "plate", 1, 650, p: 45, c: 50, f: 28, fi: 5.0, fe: 3.0),
                p("Greek Salad", "bowl", 1, 250, p: 7.0, c: 12, f: 20, fi: 3.5, fe: 1.2),
                p("Lentil Soup", "bowl", 1, 230, p: 13, c: 33, f: 5, fi: 10, fe: 4.0),
                p("Tabbouleh", "bowl", 1, 180, p: 4.0, c: 20, f: 10, fi: 4.0, fe: 2.0, "150 g"),
                p("Hummus", "serving", 1, 170, p: 8.0, c: 14, f: 10, fi: 6.0, fe: 2.4, "100 g"),
            ],
            "dinner": [
                p("Grilled Fish & Vegetables", "plate", 1, 420, p: 38, c: 15, f: 22, fi: 5.0, fe: 1.8),
                p("Chicken Kabsa", "plate", 1, 650, p: 35, c: 80, f: 20, fi: 3.0, fe: 3.0),
                p("Lamb Kofta with Rice", "plate", 1, 700, p: 35, c: 60, f: 35, fi: 3.0, fe: 4.0),
                p("Moussaka", "serving", 1, 520, p: 25, c: 25, f: 35, fi: 6.0, fe: 3.0, "300 g"),
                p("Mixed Grill", "plate", 1, 800, p: 65, c: 10, f: 55, fi: 2.0, fe: 5.0),
                p("Stuffed Vine Leaves", "piece", 6, 45, p: 1.0, c: 6, f: 2, fi: 1.0, fe: 0.3),
            ],
            "snacks": [
                p("Dates", "piece", 3, 66, p: 0.4, c: 18, f: 0, fi: 1.6, fe: 0.2),
                p("Hummus & Veg Sticks", "serving", 1, 200, p: 7.0, c: 18, f: 11, fi: 6.0, fe: 2.0),
                p("Mixed Nuts", "handful", 1, 175, p: 5.0, c: 7, f: 15, fi: 2.0, fe: 1.0, "30 g"),
                p("Baklava", "piece", 1, 245, p: 4.0, c: 29, f: 13, fi: 1.5, fe: 1.0),
                p("Olives", "serving", 1, 50, p: 0.4, c: 2.5, f: 4.5, fi: 1.2, fe: 0.6, "10 olives"),
                p("Arabic Coffee (Kahwa)", "cup", 1, 5, p: 0.1, c: 1, f: 0, fi: 0, fe: 0),
            ],
        ],
    ]
}
