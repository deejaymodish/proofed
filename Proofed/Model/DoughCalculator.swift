import Foundation

// MARK: - Inputs

enum Thickness: String, CaseIterable, Identifiable {
    case thin, regular, thick
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Dough-density factor. Values match the reference web calculator (1.8 / 2.11 / 2.75).
    var factor: Double {
        switch self {
        case .thin: 1.8
        case .regular: 2.11
        case .thick: 2.75
        }
    }
}

struct DoughInput: Equatable {
    var sizeInches: Int = 16      // 10...20
    var count: Int = 6            // 1...10
    var thickness: Thickness = .regular
    var glutenFree: Bool = false

    static let sizeRange = 10...20
    static let countRange = 1...10
}

// MARK: - Outputs

struct IngredientLine: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let note: String?
    let amount: String          // pre-formatted grams, e.g. "1705" or "6.8"
    let bakersPercent: String   // e.g. "62%"
}

struct Tip: Equatable {
    let title: String
    let message: String
}

struct DoughResult: Equatable {
    let ballGrams: Int
    let flourGrams: Int
    let waterGrams: Int
    let hydrationPercent: Int
    let ingredients: [IngredientLine]
    let doughType: String
    let restNote: String
    let summary: String
    let tip: Tip?
    let steps: [String]
}

// MARK: - Calculator

enum DoughCalculator {
    /// Reference point: 6 regular-thickness 16" pizzas.
    static let referenceSize = 16.0
    static let referenceCount = 6.0
    static let referenceThickness = 2.11

    /// Total flour (g) for the reference batch. Kept as the original expression so it can be
    /// diffed against the web source if it ever changes.
    static let regularBaseFlour = 1509.797685 * (480.0 / 425.0)   // ≈ 1705.19 g
    static let glutenFreeBaseFlour = 333.0 * 6.0                   // 1998 g

    /// Converts total flour to total dough weight when computing ball size.
    static let doughToFlourRatio = 2550.0 / 1509.797685            // ≈ 1.689

    static func calculate(_ input: DoughInput) -> DoughResult {
        let size = Double(input.sizeInches)
        let count = Double(input.count)
        let gf = input.glutenFree

        let baseFlour = gf ? glutenFreeBaseFlour : regularBaseFlour
        let flour = baseFlour
            * pow(size / referenceSize, 2)
            * (count / referenceCount)
            * (input.thickness.factor / referenceThickness)

        let hydration = gf ? 0.80 : 0.62
        let water = jsRound(flour * hydration)
        let yeast = flour * 0.004
        let salt = jsRound(flour * 0.025)
        let sugar = jsRound(flour * 0.02)
        let oil = jsRound(flour * 0.033)
        let ball = jsRound(flour * doughToFlourRatio / count)
        let flourRounded = jsRound(flour)
        let hydrationPct = jsRound(hydration * 100)

        let ingredients = [
            IngredientLine(name: gf ? "Gluten-free flour" : "Bread flour",
                           note: gf ? "A pizza-specific GF blend works best" : "12–14% protein",
                           amount: "\(flourRounded)", bakersPercent: "100%"),
            IngredientLine(name: "Water", note: "Cold, below 60°F",
                           amount: "\(water)", bakersPercent: "\(hydrationPct)%"),
            IngredientLine(name: "Yeast", note: "Active dry",
                           amount: String(format: "%.1f", yeast), bakersPercent: "0.4%"),
            IngredientLine(name: "Salt", note: nil, amount: "\(salt)", bakersPercent: "2.5%"),
            IngredientLine(name: "Sugar", note: nil, amount: "\(sugar)", bakersPercent: "2%"),
            IngredientLine(name: "Olive oil", note: nil, amount: "\(oil)", bakersPercent: "3.3%"),
        ]

        let summary = "\(input.count) ball\(input.count > 1 ? "s" : ""), \(input.sizeInches)\", \(input.thickness.rawValue)"

        return DoughResult(
            ballGrams: ball,
            flourGrams: flourRounded,
            waterGrams: water,
            hydrationPercent: hydrationPct,
            ingredients: ingredients,
            doughType: gf ? "Gluten-free" : "Regular dough",
            restNote: gf ? "Chill up to 48 hours" : "Cold ferment 2–4 days",
            summary: summary,
            tip: tip(for: input),
            steps: gf ? glutenFreeSteps : regularSteps
        )
    }

    /// Same precedence as the web version: GF > large size > big batch > thick > thin.
    static func tip(for input: DoughInput) -> Tip? {
        if input.glutenFree {
            return Tip(title: "Gluten-free", message: "This dough is tacky. Oil your hands before you shape it.")
        }
        if input.sizeInches >= 18 {
            return Tip(title: "Large pizza", message: "At \(input.sizeInches)\", give the oven a full 45-minute preheat at its highest setting.")
        }
        if input.count >= 8 {
            return Tip(title: "Big batch", message: "Shape all \(input.count) balls in one go. They hold in the fridge for up to 4 days.")
        }
        switch input.thickness {
        case .thick: return Tip(title: "Thick crust", message: "Bake at 450°F for 10–12 minutes rather than 6–8.")
        case .thin: return Tip(title: "Thin crust", message: "It's done in 4–5 minutes, so stay close to the oven.")
        case .regular: return nil
        }
    }

    static let regularSteps = [
        "Chill the water to below 60°F.",
        "Stir the yeast into the water.",
        "Add the flour and olive oil; mix for 2 minutes.",
        "Add the sugar and salt with the mixer on low.",
        "Keep mixing for another 10 minutes.",
        "Cover and let it rest for 1–3 hours.",
        "Divide into balls and pinch the seams closed.",
        "Refrigerate for 2–4 days; day 3 is the sweet spot.",
        "Let the balls come to room temperature before stretching.",
    ]

    static let glutenFreeSteps = [
        "Combine the cold water and yeast.",
        "Add the GF flour and olive oil; mix for 2 minutes.",
        "Add the sugar and salt; mix for 3–4 minutes.",
        "Chill for 15 minutes so it firms up.",
        "Oil your hands and form the balls.",
        "Refrigerate for up to 48 hours.",
        "Let the balls come to room temperature before shaping.",
    ]

    /// JavaScript's Math.round: halves round toward +∞.
    static func jsRound(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    static func shareText(input: DoughInput, result: DoughResult) -> String {
        var t = "PIZZA DOUGH\n\(input.count)× \(input.sizeInches)\" \(input.thickness.rawValue), \(result.ballGrams) g per ball\n\n"
        for i in result.ingredients { t += "\(i.name): \(i.amount) g\n" }
        t += "\n\(result.restNote)\n\nSteps:\n"
        for (n, s) in result.steps.enumerated() { t += "\(n + 1). \(s)\n" }
        return t
    }
}
