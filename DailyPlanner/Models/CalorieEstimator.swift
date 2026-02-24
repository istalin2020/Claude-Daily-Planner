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
    ]
}
