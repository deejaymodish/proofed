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

    /// The crunchy variant (semolina + diastatic malt, longer ferment) is New York only.
    var supportsCrunchy: Bool { self == .newYork }

    /// Sourdough works for every style except tavern, whose stiff cracker dough is built around
    /// a short, predictable commercial-yeast rise.
    var supportsSourdough: Bool { self != .tavern }
}

/// Where the pizza is baked. This changes the browning agents and the whole bake procedure:
/// a home oven tops out around 550F and needs sugar and malt to brown, while a live-fire dome
/// oven has heat to spare and will scorch a sweetened crust before the base crisps.
enum Oven: String, CaseIterable, Identifiable {
    case home, pizzaOven

    var id: String { rawValue }
    var label: String {
        switch self {
        case .home: "Home oven"
        case .pizzaOven: "Pizza oven"
        }
    }

    /// Live fire browns on its own, so sweetener is capped low and diastatic malt is dropped.
    var isLiveFire: Bool { self == .pizzaOven }
    static let liveFireSugarCap = 0.005
}

struct DoughInput: Equatable {
    var style: Style = .classic
    var sizeInches: Int = 16      // 10...20
    var count: Int = 6            // 1...10
    var thickness: Thickness = .regular
    var glutenFree: Bool = false
    var crunchy: Bool = false
    var sourdough: Bool = false
    var oven: Oven = .home

    static let sizeRange = 10...20
    static let countRange = 1...10

    /// Gluten-free is ignored by styles that have no GF recipe.
    var effectiveGlutenFree: Bool { style.supportsGlutenFree && glutenFree }

    /// Crunchy is ignored by styles that have no crunchy variant.
    var effectiveCrunchy: Bool { style.supportsCrunchy && crunchy }

    /// Sourdough is ignored by tavern, and by the gluten-free dough: a GF starter behaves
    /// differently enough that the straight yeast-for-starter swap would not hold.
    var effectiveSourdough: Bool { style.supportsSourdough && sourdough && !effectiveGlutenFree }
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
    /// The full method: dough steps followed by the bake steps for the chosen oven.
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
    var sugar: Double
    let oil: Double
    /// Total dough weight as a multiple of flour weight, used for ball size.
    var doughRatio: Double
    let flourName: String
    let flourNote: String
    /// Optional blended flour, as a share of total flour (0 = single flour).
    var secondFlourShare: Double = 0
    var secondFlourName: String = ""
    var secondFlourNote: String = ""
    /// Sweetener label and note; honey behaves like sugar in the math but is listed by name.
    var sugarName: String = "Sugar"
    var sugarNote: String = ""
    /// Optional third flour, as a share of total flour (0 = none).
    var thirdFlourShare: Double = 0
    var thirdFlourName: String = ""
    var thirdFlourNote: String = ""
    /// Optional diastatic malt powder, as a share of flour (0 = none).
    var malt: Double = 0
    /// Optional sourdough starter, as a share of total flour (0 = commercial yeast).
    /// The starter is 100% hydration, so half its weight is flour and half is water; both are
    /// deducted from the flour and water you add, which keeps the dough's totals unchanged.
    var starterShare: Double = 0
    var starterNote: String = ""
    let waterNote: String
    let yeastNote: String
    let oilName: String
    var typeName: String
    var restNote: String
    /// Mixing and fermenting only. The bake tail comes from the style and the oven.
    var doughSteps: [String]
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
        doughSteps: [
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
        doughSteps: [
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
        doughSteps: [
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
        doughSteps: [
            "Mix the flour, yeast, sugar, and salt, then stir in the lukewarm water.",
            "Stop as soon as it holds together as a rough dough.",
            "Cover and leave it at room temperature for 12-24 hours. It gets puffy, not doubled.",
            "Divide the dough and stretch and fold each piece on all four sides.",
            "Tuck the edges under to form a smooth ball, seam down, and rest it 45-60 minutes.",
        ]
    )

    /// New York style: 900 g flour (10% whole wheat), 31 g salt, 5 g instant yeast, 27 g olive oil.
    /// The source uses 14 g sugar; we use honey instead. Honey is about 82% sugars and 17% water,
    /// so 17 g honey carries the same sweetness and its ~3 g of water comes out of the 576 g,
    /// leaving 573 g. Reference batch is four 14-16" pies (about 400 g each).
    static let newYork = Recipe(
        baseFlour: 900, refSize: 15, refCount: 4,
        hydration: 573.0 / 900, yeast: 5.0 / 900, salt: 31.0 / 900,
        sugar: 17.0 / 900, oil: 27.0 / 900,                        // honey, see note above
        doughRatio: 1 + (573.0 + 5 + 31 + 17 + 27) / 900,          // 1.7256
        flourName: "Bread flour", flourNote: "High protein, 12-14%",
        secondFlourShare: 90.0 / 900, secondFlourName: "Whole wheat flour",
        secondFlourNote: "Freshly milled if you can",
        sugarName: "Honey", sugarNote: "Stir into the water with the yeast",
        waterNote: "About 75F", yeastNote: "Instant (or 8 g fresh)", oilName: "Olive oil",
        typeName: "New York", restNote: "Cold ferment overnight, up to 24 hours",
        doughSteps: [
            "Mix the bread flour, whole wheat flour, and salt together.",
            "Whisk the yeast and honey into the water, then stir in the olive oil.",
            "Pour the wet into the dry and mix to a shaggy dough.",
            "Knead 3-5 minutes, until smooth, and shape into a ball.",
            "Put it in a greased bowl, cover tightly, and refrigerate overnight.",
            "Divide, then round each piece into a taut ball with the seam underneath.",
            "Chill until needed, or proof at room temperature about 3.5 hours to bake today.",
        ]
    )

    /// New York, crunchy variant. Same hydration, so the crumb stays chewy and open; the shell
    /// crisps from 10% semolina, 0.5% diastatic malt, a longer cold ferment and a slower bake.
    static let newYorkCrunchy: Recipe = {
        var r = Recipe.newYork
        r.secondFlourShare = 90.0 / 900          // whole wheat, unchanged
        r.thirdFlourShare = 90.0 / 900           // semolina, taken out of the bread flour
        r.thirdFlourName = "Semolina"
        r.thirdFlourNote = "Fine durum, also for dusting the peel"
        r.malt = 4.5 / 900
        r.doughRatio = 1 + (573.0 + 5 + 31 + 17 + 27 + 4.5) / 900   // 1.7306
        r.typeName = "New York, crunchy"
        r.restNote = "Cold ferment 48-72 hours"
        r.doughSteps = [
            "Mix the bread flour, whole wheat flour, semolina, salt, and malt powder together.",
            "Whisk the yeast and honey into the water, then stir in the olive oil.",
            "Pour the wet into the dry and mix to a shaggy dough.",
            "Knead 3-5 minutes, until smooth, and shape into a ball.",
            "Put it in a greased bowl, cover tightly, and refrigerate.",
            "Divide and round into taut balls, seam underneath, on day two.",
            "Cold ferment 48-72 hours total; the drier the surface gets, the better it crisps.",
        ]
        return r
    }()

    /// Standard starter level: 20% of total flour, kept at 100% hydration.
    static let starterShare = 0.20

    /// Swaps commercial yeast for a sourdough starter. Total flour, total water and hydration all
    /// stay exactly where the parent recipe put them — the starter's flour and water are simply
    /// deducted from what you weigh out, so the crumb and the ball size barely move.
    static func sourdough(_ base: Recipe, typeName: String, restNote: String,
                          doughSteps: [String]) -> Recipe {
        var r = base
        r.starterShare = starterShare
        r.starterNote = "100% hydration, fed and at its peak"
        r.doughRatio = base.doughRatio - base.yeast   // the yeast is gone; the starter is already counted
        r.typeName = typeName
        r.restNote = restNote
        r.doughSteps = doughSteps
        return r
    }

    /// Feeding the starter and judging ripeness is the same for every style.
    static let starterPrep = [
        "Feed your starter 4-6 hours ahead. It is ready when it has domed and a spoonful floats.",
    ]

    static let classicSourdough = sourdough(
        classic,
        typeName: "Sourdough",
        restNote: "Bulk 4-6 hours, then cold ferment 1-3 days",
        doughSteps: starterPrep + [
            "Mix the starter into cool water until it is milky.",
            "Add the flour and olive oil; mix for 2 minutes, then rest 20 minutes.",
            "Add the sugar and salt and mix until the dough is smooth and elastic.",
            "Bulk ferment 4-6 hours at room temperature, folding it over twice in the first 2 hours.",
            "Divide into balls and pinch the seams closed.",
            "Refrigerate 1-3 days; day 2 is the sweet spot.",
            "Let the balls come to room temperature, 2-3 hours, before stretching.",
        ]
    )

    static let neapolitanSourdough = sourdough(
        neapolitan,
        typeName: "Neapolitan sourdough",
        restNote: "Rise 16-20 hours at room temp",
        doughSteps: starterPrep + [
            "Stir the starter into lukewarm water, then add the flour, sugar, and salt.",
            "Mix until it holds together as a rough dough and leave it 30 minutes.",
            "Fold it over on itself a few times, then cover it.",
            "Leave it at room temperature 12-16 hours, until it is puffy and domed.",
            "Divide, shape into tight balls, and rest them 3-4 hours more.",
        ]
    )

    static let newYorkSourdough = sourdough(
        newYork,
        typeName: "New York sourdough",
        restNote: "Bulk 4-5 hours, then cold ferment 1-2 days",
        doughSteps: starterPrep + [
            "Mix the bread flour, whole wheat flour, and salt together.",
            "Whisk the starter and honey into the water, then stir in the olive oil.",
            "Pour the wet into the dry and mix to a shaggy dough; rest 20 minutes.",
            "Knead 3-5 minutes, until smooth, and shape into a ball.",
            "Bulk ferment 4-5 hours at room temperature, folding it twice early on.",
            "Divide, then round each piece into a taut ball with the seam underneath.",
            "Refrigerate 24-48 hours.",
        ]
    )

    static let newYorkCrunchySourdough = sourdough(
        newYorkCrunchy,
        typeName: "New York sourdough, crunchy",
        restNote: "Bulk 4-5 hours, then cold ferment 2-3 days",
        doughSteps: starterPrep + [
            "Mix the bread flour, whole wheat flour, semolina, salt, and malt powder together.",
            "Whisk the starter and honey into the water, then stir in the olive oil.",
            "Pour the wet into the dry and mix to a shaggy dough; rest 20 minutes.",
            "Knead 3-5 minutes, until smooth, and shape into a ball.",
            "Bulk ferment 4-5 hours at room temperature, folding it twice early on.",
            "Divide and round into taut balls, seam underneath.",
            "Cold ferment 48-72 hours; the drier the surface gets, the better it crisps.",
        ]
    )

    /// Adapts a recipe to a live-fire oven. Sugar and diastatic malt are there to help a 550F
    /// home oven brown; a dome oven browns on its own, and they scorch the top before the base
    /// crisps. Removing them lets the bake run long enough to actually dry the crust.
    static func liveFire(_ base: Recipe) -> Recipe {
        var r = base
        let newSugar = min(base.sugar, Oven.liveFireSugarCap)
        // Keep the ball weight honest: whatever mass we removed comes out of the dough ratio.
        r.doughRatio = base.doughRatio - (base.sugar - newSugar) - base.malt
        r.sugar = newSugar
        if base.malt > 0 {
            r.malt = 0
            // The mixing step names the malt, so it has to stop naming it.
            r.doughSteps = base.doughSteps.map {
                $0 == "Mix the bread flour, whole wheat flour, semolina, salt, and malt powder together."
                    ? "Mix the bread flour, whole wheat flour, semolina, and salt together." : $0
            }
        }
        return r
    }

    static func `for`(_ input: DoughInput) -> Recipe {
        let r = baseRecipe(for: input)
        return input.oven.isLiveFire ? liveFire(r) : r
    }

    private static func baseRecipe(for input: DoughInput) -> Recipe {
        let sour = input.effectiveSourdough
        switch input.style {
        case .neapolitan: return sour ? .neapolitanSourdough : .neapolitan
        case .newYork:
            if input.crunchy { return sour ? .newYorkCrunchySourdough : .newYorkCrunchy }
            return sour ? .newYorkSourdough : .newYork
        case .tavern: return .tavern
        case .classic:
            if input.glutenFree { return .classicGlutenFree }
            return sour ? .classicSourdough : .classic
        }
    }
}

// MARK: - Calculator

enum DoughCalculator {
    static let referenceThickness = 2.11

    // MARK: Bake steps
    //
    // Everything from "the balls are ready" onward depends on the oven, not the dough. A home
    // oven is mostly conduction from a steel, so it runs at its ceiling for a moderate bake. A
    // live-fire dome oven is mostly radiant heat from the flame and roof, which inflates the rim
    // and scorches the top long before the base crisps — so for every style but Neapolitan the
    // method is to preheat hard, then cut the flame and bake on stored stone heat.

    static func bakeSteps(for input: DoughInput) -> [String] {
        switch (input.style, input.oven) {

        case (.neapolitan, .home):
            return [
                "Preheat the oven to 500-550F with a steel or stone inside for at least 30 minutes.",
                "Press the dough out with your fingertips, leaving the outer edge untouched.",
                "Stretch it to 10-12\" on a floured peel, letting gravity do the work.",
                "Bake about 6 minutes on a steel or 7 on a stone, then broil 2-3 minutes until charred.",
            ]

        // The one style the dome oven was built for: keep the fire up and go fast.
        case (.neapolitan, .pizzaOven):
            return [
                "Run the oven hot and keep the flame up. You want the stone at 750-850F.",
                "Press the dough out with your fingertips, leaving the outer edge untouched.",
                "Stretch it to 10-12\" on a semolina-dusted peel, letting gravity do the work.",
                "Launch and bake 60-90 seconds, turning every 20-30 seconds.",
                "Pull it when the rim is puffed and leopard-spotted. Let the stone recover before the next one.",
            ]

        case (.newYork, .home):
            return input.effectiveCrunchy ? [
                "Preheat a steel at 550F convection for a full hour, then set the oven to 500F.",
                "Open the dough by hand, leaving a 1/3 inch rim, and dust the peel with semolina.",
                "Bake 8-9 minutes, then broil 60-90 seconds for color.",
                "Cool on a wire rack for 2 minutes so the bottom stays crisp.",
            ] : [
                "Preheat a steel or stone at 550F convection for a full hour.",
                "Open the dough by hand, leaving a 1/3 inch rim, then stretch it over your fists.",
                "Sauce, cheese, bake about 7 minutes, then broil 1 minute for char.",
                "Cool on a wire rack for 2 minutes so the bottom stays crisp.",
            ]

        // The hard case: a dome oven wants to make this Neapolitan. Starve the flame.
        case (.newYork, .pizzaOven):
            return [
                "Run the oven to full temperature so the stone is saturated with heat.",
                "Cut the flame to minimum or off and let it settle 10-15 minutes. The stone stays hot; the dome cools.",
                "Check the stone with an infrared thermometer before you launch: you want 550-600F, not higher.",
                "Open the dough to within 1/4 inch of the edge, pressing the gas out toward the rim, not into it.",
                "Stretch it the whole way to size on a semolina-dusted peel. Measure it the first few times.",
                "Launch and bake 6-8 minutes, turning every 60-90 seconds and keeping it away from the flame.",
                "If the top colors before the base sets, the dome is still too hot. Let it fall further next time.",
                "Relight between pies to recover the stone, then cut the flame again before the next launch.",
                "Cool on a wire rack for 2 minutes so the bottom stays crisp.",
            ]

        case (.tavern, .home):
            return [
                "Preheat a stone or steel at 475F for at least 45 minutes.",
                "Roll it very thin on a surface dusted with cornmeal or semolina.",
                "Dock the dough all over with a fork so it does not bubble.",
                "Bake 10-12 minutes, until the edges are deep brown and the base snaps.",
            ]

        case (.tavern, .pizzaOven):
            return [
                "Preheat, then cut the flame and let the oven fall back. You want the stone near 500F.",
                "Roll it very thin on a surface dusted with cornmeal or semolina.",
                "Dock the dough all over with a fork so it does not bubble.",
                "Bake 5-7 minutes, turning often. This dough is thin enough to scorch in seconds.",
            ]

        case (.classic, .home):
            return [
                "Preheat a steel or stone at 500-550F for a full hour.",
                "Open the dough, leaving a thin rim, and dust the peel with semolina.",
                "Bake 6-8 minutes, until the edges have browned and the base is set.",
                "Cool on a wire rack for 2 minutes before slicing.",
            ]

        case (.classic, .pizzaOven):
            return [
                "Run the oven to full temperature, then cut the flame and let it settle 10 minutes.",
                "Aim for a stone around 600F; much hotter and the top burns before the base crisps.",
                "Open the dough, leaving a thin rim, and dust the peel with semolina.",
                "Bake 4-6 minutes, turning every minute.",
                "Cool on a wire rack for 2 minutes before slicing.",
            ]
        }
    }

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

        // A 100% hydration starter is half flour, half water, so both come out of what you weigh.
        let starterFlourShare = recipe.starterShare / 2
        let blendedShare = recipe.secondFlourShare + recipe.thirdFlourShare
        let primaryFlourShare = 1 - blendedShare - starterFlourShare
        let addedWaterShare = recipe.hydration - starterFlourShare

        var ingredients: [IngredientLine] = [
            IngredientLine(name: recipe.flourName, note: recipe.flourNote,
                           amount: "\(jsRound(flour * primaryFlourShare))",
                           bakersPercent: percent(primaryFlourShare)),
        ]
        if recipe.secondFlourShare > 0 {
            ingredients.append(IngredientLine(name: recipe.secondFlourName, note: recipe.secondFlourNote,
                                              amount: "\(jsRound(flour * recipe.secondFlourShare))",
                                              bakersPercent: percent(recipe.secondFlourShare)))
        }
        if recipe.thirdFlourShare > 0 {
            ingredients.append(IngredientLine(name: recipe.thirdFlourName, note: recipe.thirdFlourNote,
                                              amount: "\(jsRound(flour * recipe.thirdFlourShare))",
                                              bakersPercent: percent(recipe.thirdFlourShare)))
        }
        if recipe.starterShare > 0 {
            ingredients.append(IngredientLine(name: "Sourdough starter", note: recipe.starterNote,
                                              amount: "\(jsRound(flour * recipe.starterShare))",
                                              bakersPercent: percent(recipe.starterShare)))
        }
        ingredients.append(IngredientLine(
            name: "Water",
            note: recipe.starterShare > 0 ? recipe.waterNote + "; the starter's water is already taken out"
                                          : recipe.waterNote,
            amount: "\(jsRound(flour * addedWaterShare))",
            bakersPercent: percent(addedWaterShare)))
        if recipe.starterShare == 0 {
            ingredients.append(IngredientLine(name: "Yeast", note: recipe.yeastNote,
                                              amount: String(format: "%.1f", flour * recipe.yeast),
                                              bakersPercent: percent(recipe.yeast)))
        }
        ingredients.append(IngredientLine(name: "Salt", note: nil,
                                          amount: "\(jsRound(flour * recipe.salt))",
                                          bakersPercent: percent(recipe.salt)))
        if recipe.sugar > 0 {
            ingredients.append(IngredientLine(name: recipe.sugarName,
                                              note: recipe.sugarNote.isEmpty ? nil : recipe.sugarNote,
                                              amount: "\(jsRound(flour * recipe.sugar))",
                                              bakersPercent: percent(recipe.sugar)))
        }
        if recipe.oil > 0 {
            ingredients.append(IngredientLine(name: recipe.oilName, note: nil,
                                              amount: "\(jsRound(flour * recipe.oil))",
                                              bakersPercent: percent(recipe.oil)))
        }
        if recipe.malt > 0 {
            ingredients.append(IngredientLine(name: "Diastatic malt powder", note: "Browning and crisping",
                                              amount: String(format: "%.1f", flour * recipe.malt),
                                              bakersPercent: percent(recipe.malt)))
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
            steps: recipe.doughSteps + bakeSteps(for: input)
        )
    }

    /// Sourdough outranks everything, since its timing is what goes wrong; then the per-style tips,
    /// then GF > large size > big batch > thick > thin.
    static func tip(for input: DoughInput) -> Tip? {
        // In a dome oven the fire is what decides the result, so it outranks everything else.
        if input.oven.isLiveFire {
            switch input.style {
            case .neapolitan:
                return Tip(title: "This is the oven for it",
                           message: "Keep the flame up and go fast. 60-90 seconds, turning constantly, is what puffs the rim and spots it.")
            case .newYork:
                return Tip(title: "Starve the fire",
                           message: "If the top burns before the base crisps, the dome is too hot. Cut the flame, let it settle 10-15 minutes, and bake on stored stone heat.")
            case .tavern:
                return Tip(title: "Watch it every second",
                           message: "Cracker-thin dough in a live-fire oven goes from done to black fast. Turn it constantly and pull it early.")
            case .classic:
                return Tip(title: "Let the dome cool first",
                           message: "Preheat hard, then cut the flame. A saturated stone bakes fine for several minutes after the fire is down.")
            }
        }
        if input.effectiveSourdough {
            if input.style == .neapolitan {
                return Tip(title: "Go by the dough, not the clock",
                           message: "A warm kitchen can halve these times. Shape when the dough is puffy and jiggly, not when the timer says so.")
            }
            return Tip(title: "Use the starter at its peak",
                       message: "Ripe starter is domed and smells tangy, not sharp. Past peak it has sunk, and the dough will be slack and sour.")
        }
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
            if input.effectiveCrunchy {
                return Tip(title: "Crisp comes from the bake",
                           message: "Give it the full 48-72 hour ferment, bake at 500F, and cool it on a rack. A plate steams the bottom soft.")
            }
            if input.sizeInches >= 18 {
                return Tip(title: "Going big",
                           message: "At \(input.sizeInches)\" make sure your peel and stone actually fit the pie before you stretch it.")
            }
            if input.count >= 6 {
                return Tip(title: "Weigh the honey",
                           message: "Honey sticks to everything. Weigh it straight into the water so none stays in the spoon.")
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
