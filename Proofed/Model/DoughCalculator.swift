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

enum Style: String, CaseIterable, Identifiable {
    case classic      // the web calculator's dough: 62% hydration, 2-4 day cold ferment
    case tavern       // Chicago tavern-style: low hydration, oil, cracker-thin, docked
    case neapolitan   // King Arthur style: 00 flour, 73% hydration, overnight room-temp rise
    case newYork      // Weissman style: 64% hydration, 10% whole wheat, overnight cold ferment

    var id: String { rawValue }
    var label: String {
        switch self {
        case .classic: "Classic"
        case .tavern: "Tavern"
        case .neapolitan: "Neapolitan"
        case .newYork: "New York"
        }
    }

    /// Gluten-free numbers only exist for the classic dough.
    var supportsGlutenFree: Bool { self == .classic }
}

struct DoughInput: Equatable {
    var style: Style = .classic
    var sizeInches: Int = 16      // 10...20
    var count: Int = 6            // 1...10
    var thickness: Thickness = .regular
    var glutenFree: Bool = false

    static let sizeRange = 10...20
    static let countRange = 1...10

    /// Gluten-free is ignored by styles that have no GF recipe.
    var effectiveGlutenFree: Bool { style.supportsGlutenFree && glutenFree }
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

// MARK: - Recipe definitions

/// Everything that varies between doughs. Scaling works the same way for all of them:
/// flour = baseFlour * (size/refSize)^2 * (count/refCount) * (thicknessFactor/2.11)
struct Recipe {
    let baseFlour: Double       // total flour (g) for refCount pizzas at refSize, regular thickness
    let refSize: Double
    let refCount: Double
    let hydration: Double       // water as a share of flour
    let yeast: Double
    let salt: Double
    let sugar: Double
    let oil: Double
    /// Total dough weight as a multiple of flour weight, used for ball size.
    let doughRatio: Double
    let flourName: String
    let flourNote: String
    /// Optional blended flour, as a share of total flour (0 = single flour).
    var secondFlourShare: Double = 0
    var secondFlourName: String = ""
    var secondFlourNote: String = ""
    let waterNote: String
    let yeastNote: String
    let oilName: String
    let typeName: String
    let restNote: String
    let steps: [String]
}

extension Recipe {
    /// The web calculator's dough. doughRatio here is the site's own constant, which sits slightly
    /// below the sum of its ingredients; see README "Common gotchas".
    static let classic = Recipe(
        baseFlour: 1509.797685 * (480.0 / 425.0),   // about 1705.19 g for 6 x 16"
        refSize: 16, refCount: 6,
        hydration: 0.62, yeast: 0.004, salt: 0.025, sugar: 0.02, oil: 0.033,
        doughRatio: 2550.0 / 1509.797685,
        flourName: "Bread flour", flourNote: "12-14% protein",
        waterNote: "Cold, below 60F", yeastNote: "Active dry", oilName: "Olive oil",
        typeName: "Regular dough", restNote: "Cold ferment 2-4 days",
        steps: [
            "Chill the water to below 60F.",
            "Stir the yeast into the water.",
            "Add the flour and olive oil; mix for 2 minutes.",
            "Add the sugar and salt with the mixer on low.",
            "Keep mixing for another 10 minutes.",
            "Cover and let it rest for 1-3 hours.",
            "Divide into balls and pinch the seams closed.",
            "Refrigerate for 2-4 days; day 3 is the sweet spot.",
            "Let the balls come to room temperature before stretching.",
        ]
    )

    static let classicGlutenFree = Recipe(
        baseFlour: 333.0 * 6.0,                     // 1998 g for 6 x 16"
        refSize: 16, refCount: 6,
        hydration: 0.80, yeast: 0.004, salt: 0.025, sugar: 0.02, oil: 0.033,
        doughRatio: 2550.0 / 1509.797685,
        flourName: "Gluten-free flour", flourNote: "A pizza-specific GF blend works best",
        waterNote: "Cold, below 60F", yeastNote: "Active dry", oilName: "Olive oil",
        typeName: "Gluten-free", restNote: "Chill up to 48 hours",
        steps: [
            "Combine the cold water and yeast.",
            "Add the GF flour and olive oil; mix for 2 minutes.",
            "Add the sugar and salt; mix for 3-4 minutes.",
            "Chill for 15 minutes so it firms up.",
            "Oil your hands and form the balls.",
            "Refrigerate for up to 48 hours.",
            "Let the balls come to room temperature before shaping.",
        ]
    )

    /// Chicago tavern-style: low hydration with 10% fat, rolled cracker-thin and docked.
    /// Reference batch is 300 g flour, which covers two 12" pizzas.
    static let tavern = Recipe(
        baseFlour: 300, refSize: 12, refCount: 2,
        hydration: 0.50, yeast: 0.0067, salt: 0.0233, sugar: 0.0233, oil: 0.10,
        doughRatio: 1 + 0.50 + 0.0067 + 0.0233 + 0.0233 + 0.10,   // 1.6533
        flourName: "Bread or all-purpose flour", flourNote: "Either works; bread flour is chewier",
        waterNote: "Ice cold", yeastNote: "Instant", oilName: "Neutral oil or melted butter",
        typeName: "Tavern-style", restNote: "Cold ferment 24-48 hours",
        steps: [
            "Whisk the flour, sugar, salt, and instant yeast together.",
            "Pour in the ice-cold water and the oil or melted butter.",
            "Mix until it comes together as a shaggy, stiff ball.",
            "Knead for 2-3 minutes, until smooth and even.",
            "Put it in a lightly oiled container and cover it tightly.",
            "Refrigerate for 24-48 hours.",
            "Take it out and let it sit for 30 minutes.",
            "Roll it very thin on a surface dusted with cornmeal or semolina.",
            "Dock the dough all over with a fork so it does not bubble.",
        ]
    )

    /// King Arthur's Neapolitan-style crust: 232 g "00" flour, 170 g water, 8 g salt,
    /// 1/2 tsp sugar, 1/8 tsp instant yeast, yielding two 10-12" pizzas (about 200 g per ball).
    /// No oil. Rises at room temperature overnight instead of cold fermenting.
    static let neapolitan = Recipe(
        baseFlour: 232, refSize: 11, refCount: 2,
        hydration: 170.0 / 232, yeast: 0.4 / 232, salt: 8.0 / 232, sugar: 2.0 / 232, oil: 0,
        doughRatio: 1 + (170.0 + 0.4 + 8 + 2) / 232,              // 1.7776
        flourName: "\"00\" pizza flour", flourNote: "Bread flour also works",
        waterNote: "Lukewarm, 105-115F", yeastNote: "Instant or active dry", oilName: "Olive oil",
        typeName: "Neapolitan", restNote: "Rise 12-24 hours at room temp",
        steps: [
            "Mix the flour, yeast, sugar, and salt, then stir in the lukewarm water.",
            "Stop as soon as it holds together as a rough dough.",
            "Cover and leave it at room temperature for 12-24 hours. It gets puffy, not doubled.",
            "Preheat the oven to 500-550F with a steel or stone inside for at least 30 minutes.",
            "Divide the dough and stretch and fold each piece on all four sides.",
            "Tuck the edges under to form a smooth ball, seam down, and rest it 45-60 minutes.",
            "Press the dough out with your fingertips, leaving the outer edge untouched.",
            "Stretch it to 10-12\" on a floured peel, letting gravity do the work.",
            "Bake about 6 minutes on a steel or 7 on a stone, then broil 2-3 minutes until charred.",
        ]
    )

    /// New York style: 900 g flour (10% whole wheat), 576 g water, 31 g salt, 14 g sugar,
    /// 5 g instant yeast, 27 g olive oil. Reference batch is four 14-16" pies (about 400 g each).
    static let newYork = Recipe(
        baseFlour: 900, refSize: 15, refCount: 4,
        hydration: 576.0 / 900, yeast: 5.0 / 900, salt: 31.0 / 900,
        sugar: 14.0 / 900, oil: 27.0 / 900,
        doughRatio: 1 + (576.0 + 5 + 31 + 14 + 27) / 900,          // 1.7256
        flourName: "Bread flour", flourNote: "High protein, 12-14%",
        secondFlourShare: 90.0 / 900, secondFlourName: "Whole wheat flour",
        secondFlourNote: "Freshly milled if you can",
        waterNote: "About 75F", yeastNote: "Instant (or 8 g fresh)", oilName: "Olive oil",
        typeName: "New York", restNote: "Cold ferment overnight, up to 24 hours",
        steps: [
            "Mix the bread flour, whole wheat flour, sugar, and salt together.",
            "Whisk the yeast into the water, then stir in the olive oil.",
            "Pour the wet into the dry and mix to a shaggy dough.",
            "Knead 3-5 minutes, until smooth, and shape into a ball.",
            "Put it in a greased bowl, cover tightly, and refrigerate overnight.",
            "Divide, then round each piece into a taut ball with the seam underneath.",
            "Chill until needed, or proof at room temperature about 3.5 hours to bake today.",
            "Preheat a steel or stone at 550F convection for a full hour.",
            "Open the dough by hand, leaving a 1/3 inch rim, then stretch it over your fists.",
            "Sauce, cheese, bake about 7 minutes, then broil 1 minute for char.",
        ]
    )

    static func `for`(_ input: DoughInput) -> Recipe {
        switch input.style {
        case .neapolitan: .neapolitan
        case .newYork: .newYork
        case .tavern: .tavern
        case .classic: input.glutenFree ? .classicGlutenFree : .classic
        }
    }
}

// MARK: - Calculator

enum DoughCalculator {
    static let referenceThickness = 2.11

    static func calculate(_ input: DoughInput) -> DoughResult {
        let recipe = Recipe.for(input)
        let flour = recipe.baseFlour
            * pow(Double(input.sizeInches) / recipe.refSize, 2)
            * (Double(input.count) / recipe.refCount)
            * (input.thickness.factor / referenceThickness)

        let water = jsRound(flour * recipe.hydration)
        let ball = jsRound(flour * recipe.doughRatio / Double(input.count))
        let flourRounded = jsRound(flour)
        let hydrationPct = jsRound(recipe.hydration * 100)

        var ingredients = [
            IngredientLine(name: recipe.flourName, note: recipe.flourNote,
                           amount: "\(flourRounded)", bakersPercent: "100%"),
            IngredientLine(name: "Water", note: recipe.waterNote,
                           amount: "\(water)", bakersPercent: "\(hydrationPct)%"),
            IngredientLine(name: "Yeast", note: recipe.yeastNote,
                           amount: String(format: "%.1f", flour * recipe.yeast),
                           bakersPercent: percent(recipe.yeast)),
            IngredientLine(name: "Salt", note: nil,
                           amount: "\(jsRound(flour * recipe.salt))", bakersPercent: percent(recipe.salt)),
            IngredientLine(name: "Sugar", note: nil,
                           amount: "\(jsRound(flour * recipe.sugar))", bakersPercent: percent(recipe.sugar)),
            IngredientLine(name: recipe.oilName, note: nil,
                           amount: "\(jsRound(flour * recipe.oil))", bakersPercent: percent(recipe.oil)),
        ]
        if recipe.oil == 0 { ingredients.removeLast() }
        if recipe.secondFlourShare > 0 {
            let share = recipe.secondFlourShare
            ingredients[0] = IngredientLine(name: recipe.flourName, note: recipe.flourNote,
                                            amount: "\(jsRound(flour * (1 - share)))",
                                            bakersPercent: percent(1 - share))
            ingredients.insert(IngredientLine(name: recipe.secondFlourName, note: recipe.secondFlourNote,
                                              amount: "\(jsRound(flour * share))",
                                              bakersPercent: percent(share)), at: 1)
        }

        let summary = "\(input.count) ball\(input.count > 1 ? "s" : ""), \(input.sizeInches)\", \(input.thickness.rawValue)"

        return DoughResult(
            ballGrams: ball,
            flourGrams: flourRounded,
            waterGrams: water,
            hydrationPercent: hydrationPct,
            ingredients: ingredients,
            doughType: recipe.typeName,
            restNote: recipe.restNote,
            summary: summary,
            tip: tip(for: input),
            steps: recipe.steps
        )
    }

    /// Tavern has its own tips; otherwise GF > large size > big batch > thick > thin.
    static func tip(for input: DoughInput) -> Tip? {
        if input.style == .tavern {
            if input.sizeInches >= 16 {
                return Tip(title: "Rolling this thin",
                           message: "A \(input.sizeInches)\" round is a lot of rolling. Work from the center out and rest the dough if it fights back.")
            }
            if input.thickness == .thick {
                return Tip(title: "Not really tavern",
                           message: "Tavern-style is meant to be cracker-thin. Thin or regular gets you closer to the real thing.")
            }
            return Tip(title: "Dock it",
                       message: "Prick the rolled dough all over with a fork, then bake at 475F on a stone or steel until the edges are deep brown.")
        }
        if input.style == .neapolitan {
            if input.sizeInches >= 14 {
                return Tip(title: "Bigger than intended",
                           message: "This dough is built for 10-12\". At \(input.sizeInches)\" the rim gets thin, so stretch gently and expect a flatter edge.")
            }
            return Tip(title: "Leave the rim alone",
                       message: "Never press the outer inch. That untouched edge is what puffs into the cornicione.")
        }
        if input.style == .newYork {
            if input.sizeInches >= 18 {
                return Tip(title: "Going big",
                           message: "At \(input.sizeInches)\" make sure your peel and stone actually fit the pie before you stretch it.")
            }
            return Tip(title: "Heat is everything",
                       message: "Preheat the steel at 550F convection for a full hour, then broil the last minute for char.")
        }
        if input.effectiveGlutenFree {
            return Tip(title: "Gluten-free", message: "This dough is tacky. Oil your hands before you shape it.")
        }
        if input.sizeInches >= 18 {
            return Tip(title: "Large pizza", message: "At \(input.sizeInches)\", give the oven a full 45-minute preheat at its highest setting.")
        }
        if input.count >= 8 {
            return Tip(title: "Big batch", message: "Shape all \(input.count) balls in one go. They hold in the fridge for up to 4 days.")
        }
        switch input.thickness {
        case .thick: return Tip(title: "Thick crust", message: "Bake at 450F for 10-12 minutes rather than 6-8.")
        case .thin: return Tip(title: "Thin crust", message: "It's done in 4-5 minutes, so stay close to the oven.")
        case .regular: return nil
        }
    }

    /// Trims trailing zeros: 0.025 -> "2.5%", 0.02 -> "2%", 0.004 -> "0.4%".
    static func percent(_ v: Double) -> String {
        let p = (v * 10000).rounded() / 100      // percent, 2 decimals max
        if p == p.rounded() { return "\(Int(p))%" }
        var s = String(format: "%.2f", p)
        while s.hasSuffix("0") { s.removeLast() }
        return s + "%"
    }

    /// JavaScript's Math.round: halves round toward +infinity.
    static func jsRound(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    static func shareText(input: DoughInput, result: DoughResult) -> String {
        var t = "\(result.doughType.uppercased())\n\(input.count)x \(input.sizeInches)\" \(input.thickness.rawValue), \(result.ballGrams) g per ball\n\n"
        for i in result.ingredients { t += "\(i.name): \(i.amount) g\n" }
        t += "\n\(result.restNote)\n\nSteps:\n"
        for (n, s) in result.steps.enumerated() { t += "\(n + 1). \(s)\n" }
        return t
    }
}
