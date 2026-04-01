import Foundation

// MARK: - Estimation models

struct ClarifyOption: Identifiable {
    let id = UUID()
    let label: String
    /// Calorie contribution from this question.
    /// Q1 (the "base" question) gives the primary calorie value.
    /// Q2+ give additive adjustments (e.g. sauce, cooking method).
    let calories: Int
}

struct ClarifyQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let options: [ClarifyOption]
}

enum EstimationResult {
    case known(calories: Int, portion: String)
    case needsClarification(questions: [ClarifyQuestion])
    case unknown
}

// MARK: - Estimator

final class CalorieEstimator {

    static let shared = CalorieEstimator()
    private init() {}

    func estimate(for input: String) -> EstimationResult {
        let lower = input.lowercased()
        for entry in database {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                if let qs = entry.questions, !qs.isEmpty {
                    return .needsClarification(questions: qs)
                }
                return .known(calories: entry.calories, portion: entry.portion)
            }
        }
        return .unknown
    }

    // MARK: - Internal database entry

    private struct DBEntry {
        let keywords: [String]
        let calories: Int
        let portion: String
        let questions: [ClarifyQuestion]?
    }

    // MARK: - Food database (~100 entries)
    // Convention: Q1 options give the PRIMARY (base) calorie count.
    //             Q2+ options give ADDITIVE adjustments.

    private let database: [DBEntry] = [

        // ── FRUITS ──────────────────────────────────────────────────────────
        DBEntry(keywords: ["apple"],       calories: 95,  portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["banana"],      calories: 89,  portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["orange"],      calories: 62,  portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["grape"],       calories: 62,  portion: "½ cup",      questions: nil),
        DBEntry(keywords: ["strawberr"],   calories: 50,  portion: "1 cup",      questions: nil),
        DBEntry(keywords: ["blueberr"],    calories: 84,  portion: "1 cup",      questions: nil),
        DBEntry(keywords: ["mango"],       calories: 99,  portion: "1 cup",      questions: nil),
        DBEntry(keywords: ["watermelon"],  calories: 46,  portion: "1 cup",      questions: nil),
        DBEntry(keywords: ["avocado"],     calories: 160, portion: "½ avocado",  questions: nil),
        DBEntry(keywords: ["pineapple"],   calories: 82,  portion: "1 cup",      questions: nil),
        DBEntry(keywords: ["peach"],       calories: 58,  portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["pear"],        calories: 101, portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["kiwi"],        calories: 42,  portion: "1 fruit",    questions: nil),
        DBEntry(keywords: ["cherry"],      calories: 50,  portion: "½ cup",      questions: nil),
        DBEntry(keywords: ["lemon"],       calories: 17,  portion: "1 fruit",    questions: nil),

        // ── VEGETABLES ──────────────────────────────────────────────────────
        DBEntry(keywords: ["salad", "lettuce"], calories: 15, portion: "1 cup", questions: nil),
        DBEntry(keywords: ["broccoli"],    calories: 55,  portion: "1 cup",      questions: nil),
        DBEntry(keywords: ["carrot"],      calories: 52,  portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["spinach"],     calories: 7,   portion: "1 cup raw",  questions: nil),
        DBEntry(keywords: ["cucumber"],    calories: 16,  portion: "½ cup",      questions: nil),
        DBEntry(keywords: ["tomato"],      calories: 22,  portion: "1 medium",   questions: nil),
        DBEntry(keywords: ["potato"],      calories: 163, portion: "1 medium",   questions: [
            ClarifyQuestion(prompt: "How was it prepared?", options: [
                ClarifyOption(label: "Boiled / steamed",  calories: 87),
                ClarifyOption(label: "Baked",             calories: 163),
                ClarifyOption(label: "Mashed (with butter)", calories: 220),
                ClarifyOption(label: "Roasted",           calories: 180)
            ])
        ]),
        DBEntry(keywords: ["sweet potato"], calories: 103, portion: "1 medium", questions: nil),
        DBEntry(keywords: ["corn"],         calories: 132, portion: "1 ear",     questions: nil),
        DBEntry(keywords: ["pea"],          calories: 62,  portion: "½ cup",     questions: nil),
        DBEntry(keywords: ["mushroom"],     calories: 15,  portion: "½ cup",     questions: nil),

        // ── GRAINS & CARBS ───────────────────────────────────────────────────
        DBEntry(keywords: ["oatmeal", "oat", "porridge"], calories: 150, portion: "1 cup cooked", questions: [
            ClarifyQuestion(prompt: "What size portion?", options: [
                ClarifyOption(label: "Small – ½ cup",    calories: 75),
                ClarifyOption(label: "Medium – 1 cup",   calories: 150),
                ClarifyOption(label: "Large – 1½ cups",  calories: 225)
            ]),
            ClarifyQuestion(prompt: "Any add-ins?", options: [
                ClarifyOption(label: "Plain",            calories: 0),
                ClarifyOption(label: "Honey or sugar",   calories: 60),
                ClarifyOption(label: "Fruit & nuts",     calories: 80),
                ClarifyOption(label: "Peanut butter",    calories: 95)
            ])
        ]),

        DBEntry(keywords: ["rice"], calories: 206, portion: "1 cup cooked", questions: [
            ClarifyQuestion(prompt: "How much rice?", options: [
                ClarifyOption(label: "Small – ½ cup",   calories: 103),
                ClarifyOption(label: "Medium – 1 cup",  calories: 206),
                ClarifyOption(label: "Large – 1½ cups", calories: 310)
            ])
        ]),

        DBEntry(keywords: ["pasta", "noodle", "spaghetti", "penne", "fettuccine", "linguine"], calories: 220, portion: "1 cup cooked", questions: [
            ClarifyQuestion(prompt: "What portion of pasta?", options: [
                ClarifyOption(label: "Small – 1 cup",    calories: 220),
                ClarifyOption(label: "Medium – 1½ cups", calories: 330),
                ClarifyOption(label: "Large – 2 cups",   calories: 440)
            ]),
            ClarifyQuestion(prompt: "What sauce?", options: [
                ClarifyOption(label: "Tomato / marinara", calories: 70),
                ClarifyOption(label: "Cream / alfredo",   calories: 200),
                ClarifyOption(label: "Pesto",             calories: 160),
                ClarifyOption(label: "Plain / olive oil", calories: 60)
            ])
        ]),

        DBEntry(keywords: ["bread", "toast"], calories: 79, portion: "1 slice", questions: [
            ClarifyQuestion(prompt: "How many slices?", options: [
                ClarifyOption(label: "1 slice",  calories: 79),
                ClarifyOption(label: "2 slices", calories: 158),
                ClarifyOption(label: "3 slices", calories: 237)
            ]),
            ClarifyQuestion(prompt: "Any topping?", options: [
                ClarifyOption(label: "Plain",                calories: 0),
                ClarifyOption(label: "Butter",               calories: 35),
                ClarifyOption(label: "Peanut butter",        calories: 95),
                ClarifyOption(label: "Jam / jelly",          calories: 55)
            ])
        ]),

        // ── BREAKFAST ───────────────────────────────────────────────────────
        DBEntry(keywords: ["egg", "eggs"], calories: 70, portion: "1 egg", questions: [
            ClarifyQuestion(prompt: "How many eggs?", options: [
                ClarifyOption(label: "1 egg",  calories: 70),
                ClarifyOption(label: "2 eggs", calories: 140),
                ClarifyOption(label: "3 eggs", calories: 210)
            ]),
            ClarifyQuestion(prompt: "How were they cooked?", options: [
                ClarifyOption(label: "Boiled / poached",        calories: 0),
                ClarifyOption(label: "Scrambled (with butter)", calories: 35),
                ClarifyOption(label: "Fried",                   calories: 50),
                ClarifyOption(label: "Omelette",                calories: 45)
            ])
        ]),

        DBEntry(keywords: ["pancake", "waffle"], calories: 175, portion: "2 medium", questions: [
            ClarifyQuestion(prompt: "How many?", options: [
                ClarifyOption(label: "1",  calories: 88),
                ClarifyOption(label: "2",  calories: 175),
                ClarifyOption(label: "3",  calories: 263),
                ClarifyOption(label: "4",  calories: 350)
            ]),
            ClarifyQuestion(prompt: "Toppings?", options: [
                ClarifyOption(label: "Plain",               calories: 0),
                ClarifyOption(label: "Maple syrup",         calories: 100),
                ClarifyOption(label: "Butter + syrup",      calories: 150),
                ClarifyOption(label: "Fresh fruit",         calories: 30)
            ])
        ]),

        DBEntry(keywords: ["cereal", "granola", "muesli"], calories: 150, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "Type of cereal?", options: [
                ClarifyOption(label: "Granola",            calories: 220),
                ClarifyOption(label: "Corn flakes / plain", calories: 100),
                ClarifyOption(label: "Muesli",             calories: 190),
                ClarifyOption(label: "Sugary cereal",      calories: 130)
            ])
        ]),

        DBEntry(keywords: ["yogurt", "yoghurt"], calories: 150, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Plain low-fat",        calories: 110),
                ClarifyOption(label: "Greek yogurt (plain)", calories: 130),
                ClarifyOption(label: "Flavored / fruit",     calories: 180),
                ClarifyOption(label: "Full-fat plain",       calories: 150)
            ])
        ]),

        DBEntry(keywords: ["bagel"], calories: 270, portion: "1 bagel", questions: [
            ClarifyQuestion(prompt: "Any topping?", options: [
                ClarifyOption(label: "Plain",             calories: 0),
                ClarifyOption(label: "Cream cheese",      calories: 100),
                ClarifyOption(label: "Butter",            calories: 70),
                ClarifyOption(label: "Smoked salmon",     calories: 40)
            ])
        ]),

        // ── PROTEINS ────────────────────────────────────────────────────────
        DBEntry(keywords: ["chicken"], calories: 165, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "Which cut?", options: [
                ClarifyOption(label: "Breast (skinless)",  calories: 165),
                ClarifyOption(label: "Thigh (skinless)",   calories: 209),
                ClarifyOption(label: "Drumstick",          calories: 172),
                ClarifyOption(label: "Wing",               calories: 203)
            ]),
            ClarifyQuestion(prompt: "How was it cooked?", options: [
                ClarifyOption(label: "Grilled / baked",    calories: 0),
                ClarifyOption(label: "Fried",              calories: 80),
                ClarifyOption(label: "Rotisserie",         calories: 20),
                ClarifyOption(label: "In sauce / curry",   calories: 60)
            ])
        ]),

        DBEntry(keywords: ["beef", "steak", "mince", "ground beef"], calories: 250, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "How large was the portion?", options: [
                ClarifyOption(label: "Small  – 80 g",    calories: 200),
                ClarifyOption(label: "Medium – 150 g",   calories: 375),
                ClarifyOption(label: "Large  – 200 g",   calories: 500)
            ]),
            ClarifyQuestion(prompt: "How was it cooked?", options: [
                ClarifyOption(label: "Grilled / broiled", calories: 0),
                ClarifyOption(label: "Pan-fried",         calories: 30),
                ClarifyOption(label: "In sauce / stew",   calories: 50)
            ])
        ]),

        DBEntry(keywords: ["pork", "bacon", "ham", "sausage"], calories: 242, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "What pork item?", options: [
                ClarifyOption(label: "Bacon (2 slices)",   calories: 86),
                ClarifyOption(label: "Ham (2 slices)",     calories: 68),
                ClarifyOption(label: "Pork chop (100 g)",  calories: 242),
                ClarifyOption(label: "Sausage (1 link)",   calories: 150)
            ])
        ]),

        DBEntry(keywords: ["salmon", "tuna", "fish", "tilapia", "cod", "trout", "seafood"], calories: 200, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "How was it cooked?", options: [
                ClarifyOption(label: "Grilled / baked / steamed", calories: 150),
                ClarifyOption(label: "Pan-fried",                 calories: 200),
                ClarifyOption(label: "Deep fried",                calories: 280),
                ClarifyOption(label: "Canned in water",           calories: 120)
            ])
        ]),

        DBEntry(keywords: ["shrimp", "prawn"], calories: 99, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "How was it cooked?", options: [
                ClarifyOption(label: "Grilled / steamed",  calories: 99),
                ClarifyOption(label: "Fried",              calories: 190),
                ClarifyOption(label: "In sauce / stir-fry", calories: 150)
            ])
        ]),

        DBEntry(keywords: ["tofu", "tempeh"], calories: 80, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "How was it prepared?", options: [
                ClarifyOption(label: "Plain / steamed",    calories: 80),
                ClarifyOption(label: "Fried / stir-fried", calories: 145),
                ClarifyOption(label: "In sauce",           calories: 110)
            ])
        ]),

        DBEntry(keywords: ["beans", "lentils", "chickpea", "legume"], calories: 115, portion: "½ cup", questions: [
            ClarifyQuestion(prompt: "What type and portion?", options: [
                ClarifyOption(label: "½ cup lentils",       calories: 115),
                ClarifyOption(label: "½ cup black beans",   calories: 114),
                ClarifyOption(label: "½ cup chickpeas",     calories: 134),
                ClarifyOption(label: "½ cup kidney beans",  calories: 112)
            ])
        ]),

        // ── DAIRY ───────────────────────────────────────────────────────────
        DBEntry(keywords: ["milk"], calories: 149, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Whole milk",          calories: 149),
                ClarifyOption(label: "2% milk",             calories: 122),
                ClarifyOption(label: "Skim milk",           calories: 83),
                ClarifyOption(label: "Oat / almond milk",   calories: 60)
            ])
        ]),

        DBEntry(keywords: ["cheese"], calories: 113, portion: "1 oz", questions: [
            ClarifyQuestion(prompt: "How much cheese?", options: [
                ClarifyOption(label: "1 slice – 28 g",      calories: 113),
                ClarifyOption(label: "2 slices – 56 g",     calories: 226),
                ClarifyOption(label: "Generous – 85 g",     calories: 339)
            ])
        ]),

        DBEntry(keywords: ["butter"], calories: 102, portion: "1 tbsp", questions: nil),

        // ── SNACKS ──────────────────────────────────────────────────────────
        DBEntry(keywords: ["chips", "crisps"], calories: 150, portion: "small bag", questions: [
            ClarifyQuestion(prompt: "How much?", options: [
                ClarifyOption(label: "Handful – 28 g",   calories: 150),
                ClarifyOption(label: "Medium – 56 g",    calories: 300),
                ClarifyOption(label: "Large bag – 100 g", calories: 536)
            ])
        ]),

        DBEntry(keywords: ["chocolate", "candy bar"], calories: 235, portion: "1 bar", questions: [
            ClarifyQuestion(prompt: "How much chocolate?", options: [
                ClarifyOption(label: "Small piece – 20 g", calories: 107),
                ClarifyOption(label: "Half bar – 40 g",    calories: 214),
                ClarifyOption(label: "Full bar – 80 g",    calories: 428)
            ])
        ]),

        DBEntry(keywords: ["cookie", "biscuit"], calories: 50, portion: "1 cookie", questions: [
            ClarifyQuestion(prompt: "How many cookies?", options: [
                ClarifyOption(label: "1 cookie",   calories: 50),
                ClarifyOption(label: "2 cookies",  calories: 100),
                ClarifyOption(label: "3–4 cookies", calories: 175)
            ])
        ]),

        DBEntry(keywords: ["nut", "almond", "cashew", "peanut", "walnut", "pistachio"], calories: 170, portion: "1 oz (28 g)", questions: [
            ClarifyQuestion(prompt: "How much?", options: [
                ClarifyOption(label: "Small handful – 28 g", calories: 170),
                ClarifyOption(label: "Medium – 56 g",        calories: 340),
                ClarifyOption(label: "Large – 85 g",         calories: 510)
            ])
        ]),

        DBEntry(keywords: ["popcorn"], calories: 31, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much popcorn?", options: [
                ClarifyOption(label: "1 cup air-popped",    calories: 31),
                ClarifyOption(label: "3 cups air-popped",   calories: 93),
                ClarifyOption(label: "Medium cinema bag",   calories: 500),
                ClarifyOption(label: "Microwave bag (full)", calories: 375)
            ])
        ]),

        // ── DRINKS ──────────────────────────────────────────────────────────
        DBEntry(keywords: ["coffee"], calories: 5, portion: "black coffee", questions: [
            ClarifyQuestion(prompt: "How do you take it?", options: [
                ClarifyOption(label: "Black / espresso",       calories: 5),
                ClarifyOption(label: "Latte / flat white",     calories: 120),
                ClarifyOption(label: "Cappuccino",             calories: 80),
                ClarifyOption(label: "Sugar & cream added",    calories: 150)
            ])
        ]),

        DBEntry(keywords: ["tea"], calories: 2, portion: "black tea", questions: [
            ClarifyQuestion(prompt: "How do you take it?", options: [
                ClarifyOption(label: "Plain (black / green)", calories: 2),
                ClarifyOption(label: "With milk",             calories: 20),
                ClarifyOption(label: "Milk + sugar",          calories: 40),
                ClarifyOption(label: "Chai latte",            calories: 140)
            ])
        ]),

        DBEntry(keywords: ["juice", "smoothie"], calories: 120, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Orange / apple juice",        calories: 112),
                ClarifyOption(label: "Green vegetable smoothie",    calories: 150),
                ClarifyOption(label: "Fruit smoothie (with yogurt)", calories: 250),
                ClarifyOption(label: "Vegetable juice",             calories: 50)
            ])
        ]),

        DBEntry(keywords: ["soda", "cola", "soft drink", "pop"], calories: 140, portion: "355 ml can", questions: [
            ClarifyQuestion(prompt: "What size?", options: [
                ClarifyOption(label: "Can – 355 ml",          calories: 140),
                ClarifyOption(label: "Bottle – 600 ml",       calories: 240),
                ClarifyOption(label: "Large cup – 800 ml",    calories: 320),
                ClarifyOption(label: "Diet / zero sugar",     calories: 1)
            ])
        ]),

        DBEntry(keywords: ["protein shake", "protein bar", "protein powder"], calories: 200, portion: "1 serving", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Whey shake (25 g protein)", calories: 120),
                ClarifyOption(label: "Mass gainer shake",          calories: 400),
                ClarifyOption(label: "Protein bar",                calories: 200),
                ClarifyOption(label: "Plant-based shake",          calories: 130)
            ])
        ]),

        // ── MAIN DISHES ─────────────────────────────────────────────────────
        DBEntry(keywords: ["pizza"], calories: 266, portion: "1 slice", questions: [
            ClarifyQuestion(prompt: "How many slices & what crust?", options: [
                ClarifyOption(label: "1 thin-crust slice",    calories: 200),
                ClarifyOption(label: "1 regular slice",       calories: 266),
                ClarifyOption(label: "2 regular slices",      calories: 532),
                ClarifyOption(label: "1 deep-dish slice",     calories: 340)
            ])
        ]),

        DBEntry(keywords: ["sandwich", "sub", "hoagie", "wrap"], calories: 350, portion: "1 sandwich", questions: [
            ClarifyQuestion(prompt: "What filling?", options: [
                ClarifyOption(label: "Chicken / turkey (light)", calories: 300),
                ClarifyOption(label: "Veggie / salad",           calories: 220),
                ClarifyOption(label: "Ham & cheese",             calories: 350),
                ClarifyOption(label: "BLT / beef / meatball",    calories: 480)
            ])
        ]),

        DBEntry(keywords: ["burger", "hamburger"], calories: 450, portion: "1 burger", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Veggie / chicken burger", calories: 350),
                ClarifyOption(label: "Regular beef burger",     calories: 450),
                ClarifyOption(label: "Double / large beef",     calories: 750),
                ClarifyOption(label: "Slider (small)",          calories: 250)
            ])
        ]),

        DBEntry(keywords: ["hot dog", "frankfurter"], calories: 150, portion: "1 hot dog", questions: nil),

        DBEntry(keywords: ["soup", "stew", "broth"], calories: 150, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Clear broth / miso",    calories: 30),
                ClarifyOption(label: "Vegetable",             calories: 120),
                ClarifyOption(label: "Tomato",                calories: 160),
                ClarifyOption(label: "Cream / chowder",       calories: 250)
            ])
        ]),

        DBEntry(keywords: ["sushi", "sashimi", "maki", "roll"], calories: 200, portion: "6 pieces", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Sashimi (6 pcs)",         calories: 150),
                ClarifyOption(label: "Veggie roll (6 pcs)",     calories: 170),
                ClarifyOption(label: "Regular roll (6 pcs)",    calories: 200),
                ClarifyOption(label: "Tempura roll (6 pcs)",    calories: 300)
            ])
        ]),

        DBEntry(keywords: ["curry"], calories: 300, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Vegetable curry",              calories: 180),
                ClarifyOption(label: "Chicken curry (light)",        calories: 250),
                ClarifyOption(label: "Chicken curry (rich/creamy)",  calories: 350),
                ClarifyOption(label: "Lamb / beef curry",            calories: 420)
            ])
        ]),

        DBEntry(keywords: ["fried rice"], calories: 300, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much fried rice?", options: [
                ClarifyOption(label: "Small – 1 cup",    calories: 300),
                ClarifyOption(label: "Medium – 1½ cups", calories: 450),
                ClarifyOption(label: "Large – 2 cups",   calories: 600)
            ])
        ]),

        DBEntry(keywords: ["french fries", "fries"], calories: 312, portion: "medium serving", questions: [
            ClarifyQuestion(prompt: "What size?", options: [
                ClarifyOption(label: "Small",  calories: 230),
                ClarifyOption(label: "Medium", calories: 312),
                ClarifyOption(label: "Large",  calories: 490)
            ])
        ]),

        DBEntry(keywords: ["tacos", "taco"], calories: 210, portion: "2 tacos", questions: [
            ClarifyQuestion(prompt: "What filling?", options: [
                ClarifyOption(label: "Chicken (2 tacos)", calories: 280),
                ClarifyOption(label: "Beef (2 tacos)",    calories: 340),
                ClarifyOption(label: "Fish (2 tacos)",    calories: 300),
                ClarifyOption(label: "Veggie (2 tacos)",  calories: 210)
            ])
        ]),

        DBEntry(keywords: ["burrito"], calories: 490, portion: "1 burrito", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Chicken",  calories: 490),
                ClarifyOption(label: "Beef",     calories: 570),
                ClarifyOption(label: "Veggie",   calories: 400),
                ClarifyOption(label: "Bean",     calories: 380)
            ])
        ]),

        DBEntry(keywords: ["stir fry", "stir-fry"], calories: 250, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What protein?", options: [
                ClarifyOption(label: "Vegetables only",  calories: 150),
                ClarifyOption(label: "Chicken",          calories: 250),
                ClarifyOption(label: "Beef",             calories: 320),
                ClarifyOption(label: "Tofu",             calories: 200)
            ])
        ]),

        DBEntry(keywords: ["lasagna", "lasagne"], calories: 336, portion: "1 serving", questions: nil),

        DBEntry(keywords: ["mac and cheese", "macaroni", "mac & cheese"], calories: 300, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What size serving?", options: [
                ClarifyOption(label: "Small – ½ cup",  calories: 150),
                ClarifyOption(label: "Medium – 1 cup", calories: 300),
                ClarifyOption(label: "Large – 1½ cups", calories: 450)
            ])
        ]),

        // ── SOUTH INDIAN DISHES ─────────────────────────────────────────────

        DBEntry(keywords: ["idli", "idly"], calories: 39, portion: "1 idli", questions: [
            ClarifyQuestion(prompt: "How many idlis?", options: [
                ClarifyOption(label: "2 idlis",  calories: 78),
                ClarifyOption(label: "4 idlis",  calories: 156),
                ClarifyOption(label: "6 idlis",  calories: 234)
            ]),
            ClarifyQuestion(prompt: "Served with?", options: [
                ClarifyOption(label: "Plain",              calories: 0),
                ClarifyOption(label: "Sambar",             calories: 80),
                ClarifyOption(label: "Coconut chutney",    calories: 50),
                ClarifyOption(label: "Sambar + chutney",   calories: 130)
            ])
        ]),

        DBEntry(keywords: ["dosa"], calories: 120, portion: "1 dosa", questions: [
            ClarifyQuestion(prompt: "What type of dosa?", options: [
                ClarifyOption(label: "Plain dosa",          calories: 120),
                ClarifyOption(label: "Masala dosa",         calories: 220),
                ClarifyOption(label: "Ghee / butter dosa",  calories: 190),
                ClarifyOption(label: "Onion dosa",          calories: 150)
            ]),
            ClarifyQuestion(prompt: "Served with?", options: [
                ClarifyOption(label: "Plain",               calories: 0),
                ClarifyOption(label: "Sambar",              calories: 80),
                ClarifyOption(label: "Coconut chutney",     calories: 50),
                ClarifyOption(label: "Sambar + chutney",    calories: 130)
            ])
        ]),

        DBEntry(keywords: ["masala dosa"], calories: 220, portion: "1 dosa", questions: nil),

        DBEntry(keywords: ["uttapam", "uthappam"], calories: 130, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many uttapams?", options: [
                ClarifyOption(label: "1 uttapam",    calories: 130),
                ClarifyOption(label: "2 uttapams",   calories: 260),
                ClarifyOption(label: "3 uttapams",   calories: 390)
            ])
        ]),

        DBEntry(keywords: ["vada", "medu vada", "meduvada"], calories: 97, portion: "1 vada", questions: [
            ClarifyQuestion(prompt: "How many vadas?", options: [
                ClarifyOption(label: "1 vada",   calories: 97),
                ClarifyOption(label: "2 vadas",  calories: 194),
                ClarifyOption(label: "3 vadas",  calories: 291)
            ])
        ]),

        DBEntry(keywords: ["sambar"], calories: 80, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much sambar?", options: [
                ClarifyOption(label: "½ cup",    calories: 40),
                ClarifyOption(label: "1 cup",    calories: 80),
                ClarifyOption(label: "1½ cups",  calories: 120)
            ])
        ]),

        DBEntry(keywords: ["upma", "uppuma", "uppumav"], calories: 200, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much upma?", options: [
                ClarifyOption(label: "Small – ½ cup",    calories: 100),
                ClarifyOption(label: "Medium – 1 cup",   calories: 200),
                ClarifyOption(label: "Large – 1½ cups",  calories: 300)
            ])
        ]),

        DBEntry(keywords: ["pongal", "ven pongal", "khichadi", "khichdee"], calories: 250, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Ven pongal (savoury)",  calories: 250),
                ClarifyOption(label: "Sweet pongal",          calories: 340),
                ClarifyOption(label: "Plain khichdi",         calories: 200),
                ClarifyOption(label: "Dal khichdi",           calories: 230)
            ])
        ]),

        DBEntry(keywords: ["appam", "aappam"], calories: 82, portion: "1 appam", questions: [
            ClarifyQuestion(prompt: "How many appams?", options: [
                ClarifyOption(label: "2 appams",  calories: 164),
                ClarifyOption(label: "3 appams",  calories: 246),
                ClarifyOption(label: "4 appams",  calories: 328)
            ])
        ]),

        DBEntry(keywords: ["rasam"], calories: 50, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["curd rice", "thayir sadam"], calories: 200, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["lemon rice", "elumichai sadam"], calories: 220, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["tamarind rice", "puliyogare", "pulihora"], calories: 200, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["coconut rice", "thengai sadam"], calories: 250, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["pesarattu"], calories: 120, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many?", options: [
                ClarifyOption(label: "1 pesarattu",  calories: 120),
                ClarifyOption(label: "2 pesarattu",  calories: 240),
                ClarifyOption(label: "3 pesarattu",  calories: 360)
            ])
        ]),

        DBEntry(keywords: ["puttu"], calories: 200, portion: "1 serving", questions: [
            ClarifyQuestion(prompt: "With what?", options: [
                ClarifyOption(label: "Plain",                  calories: 200),
                ClarifyOption(label: "With coconut",           calories: 250),
                ClarifyOption(label: "With banana",            calories: 290),
                ClarifyOption(label: "With kadala curry",      calories: 350)
            ])
        ]),

        DBEntry(keywords: ["bonda", "bajji", "pakora", "pakoda"], calories: 100, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "2 pieces",   calories: 200),
                ClarifyOption(label: "4 pieces",   calories: 400),
                ClarifyOption(label: "6 pieces",   calories: 600)
            ])
        ]),

        DBEntry(keywords: ["kootu"], calories: 150, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["aviyal"], calories: 130, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["payasam", "kheer payasam"], calories: 200, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Rice payasam",    calories: 200),
                ClarifyOption(label: "Semiya payasam",  calories: 220),
                ClarifyOption(label: "Moong payasam",   calories: 180)
            ])
        ]),

        // ── NORTH INDIAN DISHES ─────────────────────────────────────────────

        DBEntry(keywords: ["biryani", "biriyani"], calories: 450, portion: "1 plate (~300 g)", questions: [
            ClarifyQuestion(prompt: "What type of biryani?", options: [
                ClarifyOption(label: "Veg biryani",       calories: 350),
                ClarifyOption(label: "Chicken biryani",   calories: 450),
                ClarifyOption(label: "Mutton biryani",    calories: 550),
                ClarifyOption(label: "Prawn biryani",     calories: 400)
            ]),
            ClarifyQuestion(prompt: "Portion size?", options: [
                ClarifyOption(label: "Small – 200 g",   calories: -100),
                ClarifyOption(label: "Regular – 300 g", calories: 0),
                ClarifyOption(label: "Large – 500 g",   calories: 200)
            ])
        ]),

        DBEntry(keywords: ["roti", "chapati", "chapatti", "phulka"], calories: 100, portion: "1 roti", questions: [
            ClarifyQuestion(prompt: "How many rotis?", options: [
                ClarifyOption(label: "1 roti",   calories: 100),
                ClarifyOption(label: "2 rotis",  calories: 200),
                ClarifyOption(label: "3 rotis",  calories: 300),
                ClarifyOption(label: "4 rotis",  calories: 400)
            ]),
            ClarifyQuestion(prompt: "With ghee?", options: [
                ClarifyOption(label: "Plain / no ghee",    calories: 0),
                ClarifyOption(label: "Light ghee",         calories: 40),
                ClarifyOption(label: "Generous ghee",      calories: 80)
            ])
        ]),

        DBEntry(keywords: ["naan"], calories: 260, portion: "1 naan", questions: [
            ClarifyQuestion(prompt: "What type of naan?", options: [
                ClarifyOption(label: "Plain naan",       calories: 260),
                ClarifyOption(label: "Butter naan",      calories: 320),
                ClarifyOption(label: "Garlic naan",      calories: 290),
                ClarifyOption(label: "Stuffed naan",     calories: 380)
            ])
        ]),

        DBEntry(keywords: ["paratha", "parantha"], calories: 200, portion: "1 paratha", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Plain paratha",        calories: 180),
                ClarifyOption(label: "Aloo paratha",         calories: 260),
                ClarifyOption(label: "Paneer paratha",       calories: 300),
                ClarifyOption(label: "Gobi / methi paratha", calories: 240)
            ]),
            ClarifyQuestion(prompt: "With ghee / butter?", options: [
                ClarifyOption(label: "No extra ghee",   calories: 0),
                ClarifyOption(label: "Light ghee",      calories: 40),
                ClarifyOption(label: "Generous ghee",   calories: 80)
            ])
        ]),

        DBEntry(keywords: ["dal", "daal", "dal tadka", "dal makhani", "dal fry"], calories: 180, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type of dal?", options: [
                ClarifyOption(label: "Plain toor / moong dal",  calories: 120),
                ClarifyOption(label: "Dal tadka",               calories: 180),
                ClarifyOption(label: "Dal fry",                 calories: 200),
                ClarifyOption(label: "Dal makhani",             calories: 300)
            ])
        ]),

        DBEntry(keywords: ["paneer"], calories: 265, portion: "100 g", questions: [
            ClarifyQuestion(prompt: "What paneer dish?", options: [
                ClarifyOption(label: "Palak paneer (1 cup)",         calories: 250),
                ClarifyOption(label: "Paneer butter masala (1 cup)", calories: 350),
                ClarifyOption(label: "Shahi paneer (1 cup)",         calories: 380),
                ClarifyOption(label: "Kadai paneer (1 cup)",         calories: 300)
            ])
        ]),

        DBEntry(keywords: ["butter chicken", "murgh makhani", "makhani"], calories: 350, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much?", options: [
                ClarifyOption(label: "½ cup (side portion)",    calories: 175),
                ClarifyOption(label: "1 cup (main portion)",    calories: 350),
                ClarifyOption(label: "1½ cups (large)",         calories: 525)
            ])
        ]),

        DBEntry(keywords: ["chole", "chana masala", "chhole"], calories: 200, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much?", options: [
                ClarifyOption(label: "½ cup",   calories: 100),
                ClarifyOption(label: "1 cup",   calories: 200),
                ClarifyOption(label: "1½ cups", calories: 300)
            ])
        ]),

        DBEntry(keywords: ["rajma"], calories: 210, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "Portion size?", options: [
                ClarifyOption(label: "½ cup",   calories: 105),
                ClarifyOption(label: "1 cup",   calories: 210),
                ClarifyOption(label: "1½ cups", calories: 315)
            ])
        ]),

        DBEntry(keywords: ["pav bhaji"], calories: 400, portion: "1 plate", questions: [
            ClarifyQuestion(prompt: "How many pavs?", options: [
                ClarifyOption(label: "Bhaji only (1 cup)",         calories: 200),
                ClarifyOption(label: "1 pav + bhaji",              calories: 330),
                ClarifyOption(label: "2 pavs + bhaji (full plate)", calories: 400)
            ])
        ]),

        DBEntry(keywords: ["samosa"], calories: 150, portion: "1 samosa", questions: [
            ClarifyQuestion(prompt: "How many samosas?", options: [
                ClarifyOption(label: "1 samosa",   calories: 150),
                ClarifyOption(label: "2 samosas",  calories: 300),
                ClarifyOption(label: "3 samosas",  calories: 450)
            ])
        ]),

        DBEntry(keywords: ["poha", "aval", "beaten rice"], calories: 250, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "Portion size?", options: [
                ClarifyOption(label: "Small – ½ cup",   calories: 125),
                ClarifyOption(label: "Medium – 1 cup",  calories: 250),
                ClarifyOption(label: "Large – 1½ cups", calories: 375)
            ])
        ]),

        DBEntry(keywords: ["aloo gobi", "alu gobi"], calories: 150, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["palak paneer"], calories: 250, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["kadai chicken", "karahi chicken"], calories: 280, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["tandoori chicken"], calories: 165, portion: "100 g (2 pieces)", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece – 100 g",   calories: 165),
                ClarifyOption(label: "2 pieces – 200 g",  calories: 330),
                ClarifyOption(label: "Half bird – 300 g", calories: 495)
            ])
        ]),

        DBEntry(keywords: ["seekh kebab", "sheek kebab"], calories: 140, portion: "1 skewer", questions: [
            ClarifyQuestion(prompt: "How many skewers?", options: [
                ClarifyOption(label: "1 skewer",   calories: 140),
                ClarifyOption(label: "2 skewers",  calories: 280),
                ClarifyOption(label: "3 skewers",  calories: 420)
            ])
        ]),

        DBEntry(keywords: ["lassi"], calories: 180, portion: "1 glass (300 ml)", questions: [
            ClarifyQuestion(prompt: "What type of lassi?", options: [
                ClarifyOption(label: "Sweet lassi",       calories: 250),
                ClarifyOption(label: "Salted / plain",    calories: 120),
                ClarifyOption(label: "Mango lassi",       calories: 300),
                ClarifyOption(label: "Rose lassi",        calories: 270)
            ])
        ]),

        DBEntry(keywords: ["kheer"], calories: 200, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "How much kheer?", options: [
                ClarifyOption(label: "½ cup",   calories: 100),
                ClarifyOption(label: "1 cup",   calories: 200),
                ClarifyOption(label: "1½ cups", calories: 300)
            ])
        ]),

        DBEntry(keywords: ["gulab jamun"], calories: 150, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece",   calories: 150),
                ClarifyOption(label: "2 pieces",  calories: 300),
                ClarifyOption(label: "3 pieces",  calories: 450)
            ])
        ]),

        DBEntry(keywords: ["jalebi"], calories: 150, portion: "2 pieces", questions: [
            ClarifyQuestion(prompt: "How many jalebis?", options: [
                ClarifyOption(label: "2 pieces (small serving)",  calories: 150),
                ClarifyOption(label: "4 pieces (medium serving)", calories: 300),
                ClarifyOption(label: "6 pieces (large serving)",  calories: 450)
            ])
        ]),

        DBEntry(keywords: ["halwa", "halva", "suji halwa", "gajar halwa", "carrot halwa"], calories: 280, portion: "1 cup", questions: [
            ClarifyQuestion(prompt: "What type of halwa?", options: [
                ClarifyOption(label: "Suji / semolina halwa", calories: 280),
                ClarifyOption(label: "Gajar / carrot halwa",  calories: 300),
                ClarifyOption(label: "Moong dal halwa",       calories: 350),
                ClarifyOption(label: "Badam / almond halwa",  calories: 400)
            ])
        ]),

        DBEntry(keywords: ["raita"], calories: 80, portion: "½ cup", questions: [
            ClarifyQuestion(prompt: "Type of raita?", options: [
                ClarifyOption(label: "Plain / boondi",   calories: 80),
                ClarifyOption(label: "Cucumber",         calories: 65),
                ClarifyOption(label: "Mixed vegetable",  calories: 90),
                ClarifyOption(label: "Onion",            calories: 75)
            ])
        ]),

        DBEntry(keywords: ["kulcha", "amritsari kulcha"], calories: 280, portion: "1 kulcha", questions: [
            ClarifyQuestion(prompt: "Type?", options: [
                ClarifyOption(label: "Plain kulcha",        calories: 260),
                ClarifyOption(label: "Aloo stuffed kulcha", calories: 350),
                ClarifyOption(label: "Paneer kulcha",       calories: 380)
            ])
        ]),

        DBEntry(keywords: ["kachori"], calories: 160, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many?", options: [
                ClarifyOption(label: "1 kachori",   calories: 160),
                ClarifyOption(label: "2 kachoris",  calories: 320),
                ClarifyOption(label: "3 kachoris",  calories: 480)
            ])
        ]),

        DBEntry(keywords: ["puri", "poori"], calories: 140, portion: "2 puris", questions: [
            ClarifyQuestion(prompt: "How many puris?", options: [
                ClarifyOption(label: "2 puris",   calories: 140),
                ClarifyOption(label: "4 puris",   calories: 280),
                ClarifyOption(label: "6 puris",   calories: 420)
            ])
        ]),

        DBEntry(keywords: ["aloo sabzi", "aloo ki sabzi", "aloo matar"], calories: 160, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["bhindi", "okra sabzi"], calories: 90, portion: "1 cup", questions: nil),

        DBEntry(keywords: ["methi", "fenugreek sabzi"], calories: 100, portion: "1 cup", questions: nil),

        // ── DESSERTS ────────────────────────────────────────────────────────
        DBEntry(keywords: ["ice cream", "gelato", "sorbet"], calories: 137, portion: "½ cup", questions: [
            ClarifyQuestion(prompt: "How much?", options: [
                ClarifyOption(label: "1 small scoop – ½ cup", calories: 137),
                ClarifyOption(label: "2 scoops – 1 cup",      calories: 274),
                ClarifyOption(label: "Large / sundae",         calories: 420)
            ])
        ]),

        DBEntry(keywords: ["cake", "cupcake"], calories: 350, portion: "1 slice", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Cupcake",            calories: 250),
                ClarifyOption(label: "Slice of layer cake", calories: 350),
                ClarifyOption(label: "Cheesecake slice",   calories: 400),
                ClarifyOption(label: "Light sponge slice", calories: 200)
            ])
        ]),

        DBEntry(keywords: ["donut", "doughnut"], calories: 253, portion: "1 donut", questions: nil),
        DBEntry(keywords: ["muffin"], calories: 340, portion: "1 large",            questions: nil),
        DBEntry(keywords: ["brownie"], calories: 180, portion: "1 piece",           questions: nil),

        // ── INDIAN SWEETS & SNACKS ───────────────────────────────────────────

        DBEntry(keywords: ["sweet", "mithai", "indian sweet"], calories: 150, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "What type of sweet?", options: [
                ClarifyOption(label: "Ladoo / laddoo",        calories: 175),
                ClarifyOption(label: "Barfi / burfi",         calories: 160),
                ClarifyOption(label: "Peda",                  calories: 130),
                ClarifyOption(label: "Rasgulla (1 piece)",    calories: 120)
            ]),
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece",   calories: 0),
                ClarifyOption(label: "2 pieces",  calories: 150),
                ClarifyOption(label: "3 pieces",  calories: 300)
            ])
        ]),

        DBEntry(keywords: ["ladoo", "laddoo", "motichoor", "besan ladoo", "rava ladoo", "coconut ladoo"], calories: 175, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many ladoos?", options: [
                ClarifyOption(label: "1 ladoo",   calories: 175),
                ClarifyOption(label: "2 ladoos",  calories: 350),
                ClarifyOption(label: "3 ladoos",  calories: 525)
            ])
        ]),

        DBEntry(keywords: ["barfi", "burfi", "kaju katli", "kaju barfi"], calories: 160, portion: "1 piece (30 g)", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece",   calories: 160),
                ClarifyOption(label: "2 pieces",  calories: 320),
                ClarifyOption(label: "3 pieces",  calories: 480)
            ])
        ]),

        DBEntry(keywords: ["rasgulla", "rasagulla"], calories: 120, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many rasgullas?", options: [
                ClarifyOption(label: "1 piece",   calories: 120),
                ClarifyOption(label: "2 pieces",  calories: 240),
                ClarifyOption(label: "3 pieces",  calories: 360)
            ])
        ]),

        DBEntry(keywords: ["sandesh", "sondesh"], calories: 110, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece",   calories: 110),
                ClarifyOption(label: "2 pieces",  calories: 220),
                ClarifyOption(label: "3 pieces",  calories: 330)
            ])
        ]),

        DBEntry(keywords: ["mysore pak", "mysorepak"], calories: 200, portion: "1 piece (40 g)", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece",   calories: 200),
                ClarifyOption(label: "2 pieces",  calories: 400),
                ClarifyOption(label: "3 pieces",  calories: 600)
            ])
        ]),

        DBEntry(keywords: ["balushahi", "badushah"], calories: 180, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many?", options: [
                ClarifyOption(label: "1 piece",   calories: 180),
                ClarifyOption(label: "2 pieces",  calories: 360),
                ClarifyOption(label: "3 pieces",  calories: 540)
            ])
        ]),

        DBEntry(keywords: ["imarti"], calories: 130, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many?", options: [
                ClarifyOption(label: "1 piece",   calories: 130),
                ClarifyOption(label: "2 pieces",  calories: 260),
                ClarifyOption(label: "3 pieces",  calories: 390)
            ])
        ]),

        DBEntry(keywords: ["chakli", "murukku", "chakri"], calories: 70, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "2 pieces",    calories: 140),
                ClarifyOption(label: "4 pieces",    calories: 280),
                ClarifyOption(label: "6 pieces",    calories: 420)
            ])
        ]),

        DBEntry(keywords: ["chivda", "mixture", "namkeen mixture", "farsan"], calories: 140, portion: "½ cup (30 g)", questions: [
            ClarifyQuestion(prompt: "How much?", options: [
                ClarifyOption(label: "½ cup – 30 g",  calories: 140),
                ClarifyOption(label: "1 cup – 60 g",  calories: 280),
                ClarifyOption(label: "1½ cups – 90 g", calories: 420)
            ])
        ]),

        DBEntry(keywords: ["mathri", "namak para", "nimki"], calories: 80, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many?", options: [
                ClarifyOption(label: "2 pieces",   calories: 160),
                ClarifyOption(label: "4 pieces",   calories: 320),
                ClarifyOption(label: "6 pieces",   calories: 480)
            ])
        ]),

        DBEntry(keywords: ["dhokla", "khaman"], calories: 75, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "2 pieces",   calories: 150),
                ClarifyOption(label: "4 pieces",   calories: 300),
                ClarifyOption(label: "6 pieces",   calories: 450)
            ])
        ]),

        DBEntry(keywords: ["khakhra"], calories: 50, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many khakhras?", options: [
                ClarifyOption(label: "1 piece",   calories: 50),
                ClarifyOption(label: "2 pieces",  calories: 100),
                ClarifyOption(label: "3 pieces",  calories: 150)
            ])
        ]),

        DBEntry(keywords: ["pani puri", "gol gappa", "puchka"], calories: 200, portion: "6 pieces (1 plate)", questions: [
            ClarifyQuestion(prompt: "How many plates?", options: [
                ClarifyOption(label: "½ plate – 3 pcs",  calories: 100),
                ClarifyOption(label: "1 plate – 6 pcs",  calories: 200),
                ClarifyOption(label: "2 plates – 12 pcs", calories: 400)
            ])
        ]),

        DBEntry(keywords: ["bhel puri", "bhelpuri"], calories: 180, portion: "1 cup (1 serving)", questions: nil),

        DBEntry(keywords: ["sev puri", "sevpuri"], calories: 200, portion: "1 plate (4 pcs)", questions: nil),

        DBEntry(keywords: ["dahi puri", "dahi puchka"], calories: 250, portion: "1 plate (6 pcs)", questions: nil),

        DBEntry(keywords: ["papdi chaat", "aloo chaat", "chaat"], calories: 220, portion: "1 plate", questions: [
            ClarifyQuestion(prompt: "What type of chaat?", options: [
                ClarifyOption(label: "Papdi chaat",       calories: 220),
                ClarifyOption(label: "Aloo chaat",        calories: 250),
                ClarifyOption(label: "Dahi bhalla chaat", calories: 280),
                ClarifyOption(label: "Basket chaat",      calories: 350)
            ])
        ]),

        // ── FAST FOOD ────────────────────────────────────────────────────────

        DBEntry(keywords: ["mcdonalds", "mc donalds", "mcdonald"], calories: 500, portion: "meal", questions: [
            ClarifyQuestion(prompt: "What did you order?", options: [
                ClarifyOption(label: "McAloo Tikki / Veg burger",   calories: 380),
                ClarifyOption(label: "Chicken burger",               calories: 450),
                ClarifyOption(label: "Big Mac / Double Beef",        calories: 560),
                ClarifyOption(label: "Happy Meal (burger + fries)",  calories: 500)
            ])
        ]),

        DBEntry(keywords: ["kfc"], calories: 550, portion: "meal", questions: [
            ClarifyQuestion(prompt: "What did you order?", options: [
                ClarifyOption(label: "2-piece chicken",             calories: 400),
                ClarifyOption(label: "Crispy chicken burger",       calories: 490),
                ClarifyOption(label: "3-piece meal + fries",        calories: 700),
                ClarifyOption(label: "Popcorn chicken (small)",     calories: 280)
            ])
        ]),

        DBEntry(keywords: ["dominos", "domino's", "pizza hut"], calories: 600, portion: "2 slices", questions: [
            ClarifyQuestion(prompt: "What size pizza / how many slices?", options: [
                ClarifyOption(label: "1 medium slice",          calories: 250),
                ClarifyOption(label: "2 medium slices",         calories: 500),
                ClarifyOption(label: "2 large slices",          calories: 600),
                ClarifyOption(label: "Personal pizza (6 slices)", calories: 900)
            ])
        ]),

        DBEntry(keywords: ["subway"], calories: 400, portion: "6-inch sub", questions: [
            ClarifyQuestion(prompt: "What size & filling?", options: [
                ClarifyOption(label: "6-inch veggie sub",       calories: 280),
                ClarifyOption(label: "6-inch chicken sub",      calories: 380),
                ClarifyOption(label: "Footlong veggie",         calories: 560),
                ClarifyOption(label: "Footlong chicken",        calories: 760)
            ])
        ]),

        DBEntry(keywords: ["noodles", "maggi", "instant noodles", "ramen"], calories: 350, portion: "1 packet cooked", questions: [
            ClarifyQuestion(prompt: "What type?", options: [
                ClarifyOption(label: "Maggi 2-minute noodles (1 pack)", calories: 350),
                ClarifyOption(label: "Instant ramen (1 pack)",          calories: 380),
                ClarifyOption(label: "Foxtail millet noodles – 1 cup",  calories: 200),
                ClarifyOption(label: "Foxtail millet noodles – 1½ cups", calories: 300)
            ])
        ]),

        DBEntry(keywords: ["spring roll", "springroll"], calories: 130, portion: "1 roll", questions: [
            ClarifyQuestion(prompt: "How many spring rolls?", options: [
                ClarifyOption(label: "1 roll",   calories: 130),
                ClarifyOption(label: "2 rolls",  calories: 260),
                ClarifyOption(label: "3 rolls",  calories: 390)
            ])
        ]),

        DBEntry(keywords: ["momos", "momo", "dumpling", "dim sum"], calories: 200, portion: "6 pieces", questions: [
            ClarifyQuestion(prompt: "How many momos?", options: [
                ClarifyOption(label: "6 steamed momos",   calories: 200),
                ClarifyOption(label: "6 fried momos",     calories: 280),
                ClarifyOption(label: "8 steamed momos",   calories: 267),
                ClarifyOption(label: "8 fried momos",     calories: 373)
            ])
        ]),

        DBEntry(keywords: ["panipuri", "golgappa", "gupchup"], calories: 200, portion: "6 pieces", questions: nil),

        DBEntry(keywords: ["vada pav", "wadapav"], calories: 290, portion: "1 piece", questions: [
            ClarifyQuestion(prompt: "How many vada pavs?", options: [
                ClarifyOption(label: "1 vada pav",   calories: 290),
                ClarifyOption(label: "2 vada pavs",  calories: 580)
            ])
        ]),

        DBEntry(keywords: ["misal pav", "misalpav"], calories: 350, portion: "1 plate", questions: nil),

        DBEntry(keywords: ["fried chicken", "crispy chicken"], calories: 350, portion: "1 piece (100 g)", questions: [
            ClarifyQuestion(prompt: "How many pieces?", options: [
                ClarifyOption(label: "1 piece – 100 g",  calories: 350),
                ClarifyOption(label: "2 pieces – 200 g", calories: 700),
                ClarifyOption(label: "3 pieces – 300 g", calories: 1050)
            ])
        ]),

        DBEntry(keywords: ["onion rings", "onion ring"], calories: 270, portion: "medium serving", questions: [
            ClarifyQuestion(prompt: "What size?", options: [
                ClarifyOption(label: "Small",  calories: 180),
                ClarifyOption(label: "Medium", calories: 270),
                ClarifyOption(label: "Large",  calories: 400)
            ])
        ]),

        DBEntry(keywords: ["milkshake", "milk shake", "frappe"], calories: 450, portion: "medium (400 ml)", questions: [
            ClarifyQuestion(prompt: "What size & flavour?", options: [
                ClarifyOption(label: "Small chocolate shake",   calories: 350),
                ClarifyOption(label: "Medium vanilla shake",    calories: 450),
                ClarifyOption(label: "Large strawberry shake",  calories: 600),
                ClarifyOption(label: "Thick oreo frappe",       calories: 550)
            ])
        ]),

        DBEntry(keywords: ["hot chocolate", "hot cocoa"], calories: 200, portion: "1 mug (250 ml)", questions: [
            ClarifyQuestion(prompt: "What size?", options: [
                ClarifyOption(label: "Small – 200 ml",         calories: 160),
                ClarifyOption(label: "Regular – 250 ml",       calories: 200),
                ClarifyOption(label: "Large with cream",        calories: 320)
            ])
        ]),
    ]
}
