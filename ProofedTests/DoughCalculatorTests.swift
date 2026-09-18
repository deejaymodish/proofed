import XCTest
@testable import Proofed

/// Classic values are golden numbers from the reference web calculator (dg-calculator.js).
/// Tavern values scale the published 300 g / two 12" pizzas recipe.
final class DoughCalculatorTests: XCTestCase {
    private func run(_ size: Int, _ count: Int, _ t: Thickness = .regular,
                     style: Style = .classic, gf: Bool = false) -> DoughResult {
        DoughCalculator.calculate(DoughInput(style: style, sizeInches: size, count: count,
                                             thickness: t, glutenFree: gf))
    }

    private func amounts(_ r: DoughResult) -> [String] { r.ingredients.map(\.amount) }
    private func percents(_ r: DoughResult) -> [String] { r.ingredients.map(\.bakersPercent) }

    // MARK: Classic

    func testDefaultRegular() {
        let r = run(16, 6)
        XCTAssertEqual(r.ballGrams, 480)
        XCTAssertEqual(r.flourGrams, 1705)
        XCTAssertEqual(r.waterGrams, 1057)
        XCTAssertEqual(r.hydrationPercent, 62)
        XCTAssertEqual(amounts(r), ["1705", "1057", "6.8", "43", "34", "56"])
        XCTAssertEqual(percents(r), ["100%", "62%", "0.4%", "2.5%", "2%", "3.3%"])
        XCTAssertNil(r.tip)
    }

    func testGlutenFree() {
        let r = run(16, 6, gf: true)
        XCTAssertEqual(r.ballGrams, 562)
        XCTAssertEqual(amounts(r), ["1998", "1598", "8.0", "50", "40", "66"])
        XCTAssertEqual(r.hydrationPercent, 80)
        XCTAssertEqual(r.tip?.title, "Gluten-free")
    }

    func testThinSingleSmall() {
        let r = run(10, 1, .thin)
        XCTAssertEqual(r.ballGrams, 160)
        XCTAssertEqual(amounts(r), ["95", "59", "0.4", "2", "2", "3"])
        XCTAssertEqual(r.tip?.title, "Thin crust")
    }

    func testThickLargeBatch() {
        let r = run(20, 10, .thick)
        XCTAssertEqual(r.ballGrams, 977)
        XCTAssertEqual(amounts(r), ["5787", "3588", "23.1", "145", "116", "191"])
        XCTAssertEqual(r.tip?.title, "Large pizza")   // size tip outranks batch and thickness
    }

    func testSmallBatch() {
        let r = run(12, 2)
        XCTAssertEqual(r.ballGrams, 270)
        XCTAssertEqual(amounts(r), ["320", "198", "1.3", "8", "6", "11"])
    }

    // MARK: Tavern

    /// The published recipe: 300 g flour, 150 g water, 30 g oil, 7 g sugar, 7 g salt.
    func testTavernMatchesSourceRecipe() {
        let r = run(12, 2, style: .tavern)
        XCTAssertEqual(amounts(r), ["300", "150", "2.0", "7", "7", "30"])
        XCTAssertEqual(percents(r), ["100%", "50%", "0.67%", "2.33%", "2.33%", "10%"])
        XCTAssertEqual(r.hydrationPercent, 50)
        XCTAssertEqual(r.ballGrams, 248)
        XCTAssertEqual(r.doughType, "Tavern-style")
        XCTAssertEqual(r.tip?.title, "Dock it")
    }

    func testTavernScales() {
        let r = run(14, 4, style: .tavern)
        XCTAssertEqual(amounts(r), ["817", "408", "5.5", "19", "19", "82"])
        XCTAssertEqual(r.ballGrams, 338)
    }

    func testTavernThinSingle() {
        let r = run(12, 1, .thin, style: .tavern)
        XCTAssertEqual(amounts(r), ["128", "64", "0.9", "3", "3", "13"])
        XCTAssertEqual(r.ballGrams, 212)
    }

    func testTavernIgnoresGlutenFreeToggle() {
        let withToggle = run(12, 2, style: .tavern, gf: true)
        let without = run(12, 2, style: .tavern)
        XCTAssertEqual(withToggle, without)
    }

    func testTavernTipsBySizeAndThickness() {
        XCTAssertEqual(run(16, 2, style: .tavern).tip?.title, "Rolling this thin")
        XCTAssertEqual(run(12, 2, .thick, style: .tavern).tip?.title, "Not really tavern")
    }

    // MARK: Neapolitan (King Arthur)

    /// Source recipe: 232 g "00" flour, 170 g water, 8 g salt, 2 g sugar, 1/8 tsp yeast; no oil.
    func testNeapolitanMatchesSourceRecipe() {
        let r = run(11, 2, style: .neapolitan)
        XCTAssertEqual(amounts(r), ["232", "170", "0.4", "8", "2"])   // no oil row
        XCTAssertEqual(r.ingredients.count, 5)
        XCTAssertEqual(r.hydrationPercent, 73)
        XCTAssertEqual(r.ballGrams, 206)
        XCTAssertEqual(r.restNote, "Rise 12-24 hours at room temp")
        XCTAssertEqual(r.tip?.title, "Leave the rim alone")
    }

    func testNeapolitanScales() {
        let r = run(12, 2, style: .neapolitan)
        XCTAssertEqual(amounts(r), ["276", "202", "0.5", "10", "2"])
        XCTAssertEqual(r.ballGrams, 245)
    }

    func testNeapolitanLargeTip() {
        XCTAssertEqual(run(16, 4, .thin, style: .neapolitan).tip?.title, "Bigger than intended")
    }

    // MARK: New York (blended flour)

    /// Source recipe: 810 g bread + 90 g whole wheat, 576 g water, 31 g salt, 14 g sugar,
    /// 5 g instant yeast, 27 g olive oil.
    func testNewYorkMatchesSourceRecipe() {
        let r = run(15, 4, style: .newYork)
        XCTAssertEqual(amounts(r), ["810", "90", "576", "5.0", "31", "14", "27"])
        XCTAssertEqual(percents(r), ["90%", "10%", "64%", "0.56%", "3.44%", "1.56%", "3%"])
        XCTAssertEqual(r.flourGrams, 900)
        XCTAssertEqual(r.ballGrams, 388)
        XCTAssertEqual(r.tip?.title, "Heat is everything")
    }

    func testNewYorkScales() {
        let r = run(12, 2, style: .newYork)
        XCTAssertEqual(amounts(r), ["259", "29", "184", "1.6", "10", "4", "9"])
        XCTAssertEqual(r.ballGrams, 248)
    }

    func testNewYorkBigTip() {
        XCTAssertEqual(run(18, 2, style: .newYork).tip?.title, "Going big")
    }

    func testOnlyClassicSupportsGlutenFree() {
        XCTAssertTrue(Style.classic.supportsGlutenFree)
        for style in [Style.neapolitan, .newYork, .tavern] {
            XCTAssertFalse(style.supportsGlutenFree)
            XCTAssertEqual(run(12, 2, style: style, gf: true), run(12, 2, style: style))
        }
    }

    func testJSRoundHalvesGoUp() {
        XCTAssertEqual(DoughCalculator.jsRound(2.5), 3)
        XCTAssertEqual(DoughCalculator.jsRound(3.5), 4)
    }
}
