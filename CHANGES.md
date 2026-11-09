# Proofed — what changed

A record of how the app grew from a port of one web calculator into a four-style dough
calculator with sourdough and oven variants. Covers both targets: the SwiftUI iOS app
(`Proofed/`) and the home-screen web app (`docs/`), which carry the same math in two languages.

Repo: `github.com/deejaymodish/proofed` · Web app: `deejaymodish.github.io/proofed/`

---

## 1. Where it started

The original was a Shopify page whose calculator lived in a minified file,
`dg-calculator.js`. The formulas were recovered from it, not guessed:

```js
// recovered, formatted for readability
var bF = gf ? 333*6 : 1509.797685*(480/425),
    dF = 2550/1509.797685,
    fl = bF * Math.pow(sz/16, 2) * (qt/6) * (cT/2.11),
    wP = gf ? .8 : .62;
ball = Math.round(fl * dF / qt);
```

Two things that mattered:

- The page's static HTML showed **425 / 1708 / 1059** as placeholders; the script replaces them
  on load with **480 / 1705 / 1057**. The real default was never the one printed on the page.
- `Math.round` rounds halves toward +∞, unlike Swift's `rounded()`. Hence `jsRound`:

```swift
/// JavaScript's Math.round: halves round toward +infinity.
static func jsRound(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }
```

---

## 2. The scaling model

Every style scales the same way. Only the constants differ.

```
flour = baseFlour × (size/refSize)² × (count/refCount) × (thicknessFactor/2.11)
ball  = flour × doughRatio / count
thicknessFactor = thin 1.8 | regular 2.11 | thick 2.75
```

| style | baseFlour | reference batch | hydration | yeast | salt | sweetener | fat | doughRatio |
|---|---|---|---|---|---|---|---|---|
| classic | 1705.19 g | 6 × 16" | 62% | 0.4% | 2.5% | 2% sugar | 3.3% | 1.6890 |
| classic GF | 1998 g | 6 × 16" | 80% | 0.4% | 2.5% | 2% sugar | 3.3% | 1.6890 |
| neapolitan | 232 g | 2 × 11" | 73.28% | 0.17% | 3.45% | 0.86% sugar | — | 1.7776 |
| new york | 900 g | 4 × 15" | 63.67% | 0.56% | 3.44% | 1.89% honey | 3% | 1.7256 |
| tavern | 300 g | 2 × 12" | 50% | 0.67% | 2.33% | 2.33% sugar | 10% | 1.6533 |

Reference outputs, regular thickness, each at its own reference batch:

| | batch | ball | hydration | ingredients |
|---|---|---|---|---|
| Classic | 16" ×6 | 480 g | 62% | Bread flour 1705, Water 1057, Yeast 6.8, Salt 43, Sugar 34, Olive oil 56 |
| Classic GF | 16" ×6 | 562 g | 80% | GF flour 1998, Water 1598, Yeast 8.0, Salt 50, Sugar 40, Olive oil 66 |
| Neapolitan | 11" ×2 | 206 g | 73% | "00" flour 232, Water 170, Yeast 0.4, Salt 8, Sugar 2 |
| New York | 15" ×4 | 388 g | 64% | Bread flour 810, Whole wheat 90, Water 573, Yeast 5.0, Salt 31, Honey 17, Olive oil 27 |
| NY crunchy | 15" ×4 | 389 g | 64% | Bread flour 720, Whole wheat 90, Semolina 90, Water 573, Yeast 5.0, Salt 31, Honey 17, Olive oil 27, Malt 4.5 |
| Tavern | 12" ×2 | 248 g | 50% | Flour 300, Water 150, Yeast 2.0, Salt 7, Sugar 7, Oil/butter 30 |

Each of those reproduces its source recipe exactly at its reference batch.

---

## 3. Styles added

**Tavern** — Chicago tavern-style, from a published recipe (300 g flour, 150 g water,
30 g oil or butter, 7 g sugar, 7 g salt, 1–5 g instant yeast). Low hydration with 10% fat,
rolled cracker-thin and docked. The source gives no yield; **two 12" pizzas per 300 g batch is
our reading**, and it is the one assumption in the whole file that isn't from a source.

**Neapolitan** — King Arthur's "00" crust. 73% hydration, no oil, a 12–24 hour room-temperature
rise rather than a cold ferment. First style with an ingredient the others have: **no oil**, which
is why zero-weight rows are dropped from the table rather than printed as `0 g`.

**New York** — a Weissman-style formula. First **blended flour**: 90% bread, 10% whole wheat.

> **Known discrepancy.** The source lists both 4 × 14–16" and 2 × 19" pies from the same batch,
> and those two aren't area-consistent (760 g at 19" vs. 400 g at 14–16"). We scale from
> 4 × 15", so large-pie numbers read lower than the source's. His bigger ball is genuinely
> thicker, not just wider.

---

## 4. Honey instead of sugar (New York)

Honey is ~82% sugars and ~17% water. So **17 g honey** carries the sweetness of the source's
14 g sugar, and the ~3 g of water it brings comes out of the water: **576 g → 573 g**. Hydration
lands at 63.67% rather than a round 64%, and that is correct, not a rounding artifact.

This introduced `sugarName` / `sugarNote` on `Recipe` — honey behaves like sugar in the math but
is listed under its own name, and goes into the water with the yeast rather than the dry mix.

---

## 5. Crunchy crust (New York only)

The ask was a crunchier shell **without losing the chew**, so hydration is untouched — that's
what the crumb is made of. The crisp comes from elsewhere:

- 10% **semolina**, taken out of the bread flour (80/10/10 bread/whole-wheat/semolina)
- 0.5% **diastatic malt**, for browning
- 48–72 hour cold ferment, a 500°F bake, semolina on the peel, cooling on a rack

Built by copying the parent recipe and overriding, which is why several `Recipe` fields are
`var` rather than `let`:

```swift
static let newYorkCrunchy: Recipe = {
    var r = Recipe.newYork
    r.thirdFlourShare = 90.0 / 900          // semolina, taken out of the bread flour
    r.thirdFlourName = "Semolina"
    r.malt = 4.5 / 900
    r.doughRatio = 1 + (573.0 + 5 + 31 + 17 + 27 + 4.5) / 900
    r.typeName = "New York, crunchy"
    r.restNote = "Cold ferment 48-72 hours"
    ...
    return r
}()
```

A test pins the intent:

```swift
func testCrunchyKeepsHydration() {
    let plain = run(15, 4, style: .newYork)
    let crunchy = run(15, 4, style: .newYork, crunchy: true)
    XCTAssertEqual(plain.hydrationPercent, crunchy.hydrationPercent)
    XCTAssertEqual(plain.waterGrams, crunchy.waterGrams)
    XCTAssertEqual(plain.flourGrams, crunchy.flourGrams)
}
```

---

## 6. Sourdough (all styles except tavern)

**20% starter at 100% hydration** replaces the commercial yeast. Half the starter's weight is
flour and half is water, so both are deducted from what you weigh out. **Total flour, total water
and hydration are unchanged** — it's the same dough, leavened differently.

```swift
// A 100% hydration starter is half flour, half water, so both come out of what you weigh.
let starterFlourShare = recipe.starterShare / 2
let blendedShare = recipe.secondFlourShare + recipe.thirdFlourShare
let primaryFlourShare = 1 - blendedShare - starterFlourShare
let addedWaterShare = recipe.hydration - starterFlourShare
```

Classic at 6 × 16":

| | yeast | sourdough |
|---|---|---|
| Bread flour | 1705 g (100%) | 1535 g (90%) |
| Starter | — | 341 g (20%) |
| Water | 1057 g (62%) | 887 g (52%) |
| Yeast | 6.8 g | — |
| Ball | 480 g | 479 g |

Each variant is derived from its parent; only the timings and steps differ:

```swift
static func sourdough(_ base: Recipe, typeName: String, restNote: String,
                      doughSteps: [String]) -> Recipe {
    var r = base
    r.starterShare = starterShare
    r.starterNote = "100% hydration, fed and at its peak"
    r.doughRatio = base.doughRatio - base.yeast   // yeast is gone; the starter is already counted
    r.typeName = typeName
    r.restNote = restNote
    r.doughSteps = doughSteps
    return r
}
```

**Excluded:** tavern (its stiff cracker dough is built around a short, predictable yeast rise)
and gluten-free (a GF starter doesn't behave enough like this swap assumes).

```swift
var supportsSourdough: Bool { self != .tavern }
var effectiveSourdough: Bool { style.supportsSourdough && sourdough && !effectiveGlutenFree }
```

---

## 7. Oven type — the live-fire adaptation

Prompted by a real failure: pies in a Solo Stove at ~600°F came out puffy and Neapolitan, with a
burnt top and a soft undercarriage, at a 4-minute bake.

**The diagnosis.** A home oven is mostly *conduction* from a steel and tops out near 550°F, so
recipes written for one add sugar and malt to get browning. A dome oven is mostly *radiant* heat
from the flame and roof. That radiant heat inflates the rim and scorches the top long before the
base has had contact time — and the browning agents make it worse. The crust was burning at
4 minutes because the recipe was tuned for an oven that needs help browning.

Two things now follow from the oven setting.

**(a) Browning agents are cut.** Sweetener capped at 0.5%, malt dropped entirely:

```swift
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
```

Flour, water and hydration never change with the oven. Only the ball moves, by the mass removed:
New York 388 g → 385 g, classic 480 g → 476 g.

**(b) The bake method is replaced.** Each recipe now holds `doughSteps` (mixing and fermenting,
oven-agnostic) and the bake tail comes from `bakeSteps(for:)`, keyed on style + oven:

```swift
steps: recipe.doughSteps + bakeSteps(for: input)
```

The two ovens deliberately pull in opposite directions:

| style | home oven | pizza oven |
|---|---|---|
| Neapolitan | 500–550°F steel, ~6 min, broil to char | **flame up**, stone 750–850°F, 60–90 s, turn constantly |
| New York | 550°F convection, ~7 min | **flame off**, stone 550–600°F, 6–8 min, turn every 60–90 s |
| Tavern | 475°F, 10–12 min | flame off, stone ~500°F, 5–7 min |
| Classic | 500–550°F, 6–8 min | flame off, stone ~600°F, 4–6 min |

Neapolitan is the one style a dome oven was built for, so it keeps the fire up. Everything else
preheats hard, cuts the flame, and bakes on stored stone heat. The full New York / pizza-oven
method:

1. Run the oven to full temperature so the stone is saturated with heat.
2. Cut the flame to minimum or off and let it settle 10–15 minutes. The stone stays hot; the dome cools.
3. Check the stone with an infrared thermometer before you launch: you want 550–600°F, not higher.
4. Open the dough to within ¼ inch of the edge, pressing the gas out toward the rim, not into it.
5. Stretch it the whole way to size on a semolina-dusted peel. Measure it the first few times.
6. Launch and bake 6–8 minutes, turning every 60–90 seconds and keeping it away from the flame.
7. If the top colors before the base sets, the dome is still too hot. Let it fall further next time.
8. Relight between pies to recover the stone, then cut the flame again before the next launch.
9. Cool on a wire rack for 2 minutes so the bottom stays crisp.

---

## 8. How the options interact

| option | applies to | ignored by |
|---|---|---|
| Thickness | all | — |
| Gluten-free | classic only | neapolitan, new york, tavern |
| Crunchy | new york only | classic, neapolitan, tavern |
| Sourdough | all but tavern | tavern, and gluten-free dough |
| Oven | all | — |

A toggle that doesn't apply is hidden in both UIs rather than shown and ignored, and the model
enforces it independently so the two can't drift:

```swift
var effectiveGlutenFree: Bool { style.supportsGlutenFree && glutenFree }
var effectiveCrunchy: Bool    { style.supportsCrunchy && crunchy }
var effectiveSourdough: Bool  { style.supportsSourdough && sourdough && !effectiveGlutenFree }
```

---

## 9. Two deliverables

| | iOS app | web app |
|---|---|---|
| source | `Proofed/` (SwiftUI) | `docs/index.html` (one file) |
| install | Xcode → device, or `.ipa` via SideStore | Safari → Add to Home Screen |
| expiry | 7 days (free Apple ID) | never |
| offline | native | service worker (`docs/sw.js`) |
| storage | `@AppStorage` | `localStorage` |

Both carry the same formulas, verified against the same values. The web app is the one that
actually gets used, because a free Apple ID re-signs every 7 days.

**Bump `CACHE` in `docs/sw.js` on every `docs/` change** or phones keep serving the old version.
Currently `proofed-v7`.

---

## 10. Files

| file | what's in it |
|---|---|
| `Proofed/Model/DoughCalculator.swift` | all formulas, recipes, variants, bake steps, tips, share text |
| `Proofed/Views/CalculatorView.swift` | the single screen and its controls |
| `Proofed/Views/Theme.swift` | colors, light and dark |
| `ProofedTests/DoughCalculatorTests.swift` | 38 golden-value tests |
| `docs/index.html` | the whole web app |
| `docs/sw.js` | offline cache |
| `project.yml` | XcodeGen spec |
| `scripts/build-ipa.sh` | builds an unsigned `.ipa` for SideStore |

---

## 11. Verification status

- **Web app** — every style × oven × variant combination was executed and checked against
  hand-computed values. Home-oven output is unchanged from before the oven refactor. Live on
  Pages as `proofed-v7` (checked 2026-11-09).
- **iOS app** — **compiles, app and all 38 tests** (2026-11-09, `xcodebuild build-for-testing`
  against a generic iPhone, no simulator needed). The oven refactor had one compile error:
  `liveFire` assigns `r.sugar`, but `Recipe.sugar` was a `let`; it is now a `var`, like `malt`
  and `doughRatio`. The `steps` → `doughSteps` rename itself was clean.
- **The tests have not been run** — this Mac has no iOS simulator runtime installed. Install one
  (Xcode → Settings → Components, or `xcodebuild -downloadPlatform iOS`, several GB), then:

```bash
UDID=$(xcrun simctl list devices available -j | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next((x['udid'] for k in d for x in d[k] if 'iPhone' in x['name']),''))")
xcodebuild test -scheme Proofed -destination "id=$UDID" 2>&1 \
  | grep -E "error:|XCTAssert|Executed .* tests|TEST (SUCCEEDED|FAILED)"
```

Compile check without a simulator:

```bash
xcodebuild build-for-testing -scheme Proofed -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "error:|\*\* TEST BUILD (SUCCEEDED|FAILED)"
```

---

## 12. Assumptions worth revisiting

Everything here is a judgment call, not a sourced number. Each is one constant.

| assumption | value | where |
|---|---|---|
| Tavern yield | two 12" pies per 300 g flour | `Recipe.tavern` baseFlour / refCount |
| Neapolitan yield | two 11" pies (source says 10–12") | `Recipe.neapolitan` refSize |
| New York yield | four 15" pies (source says 14–16") | `Recipe.newYork` refSize |
| Neapolitan yeast | 0.4 g (our gram conversion of ⅛ tsp) | `Recipe.neapolitan` yeast |
| Tavern yeast | 2 g (middle of the source's 1–5 g) | `Recipe.tavern` yeast |
| Honey conversion | honey is 82% sugars → 17 g replaces 14 g sugar | `Recipe.newYork` sugar |
| Starter level | 20% of flour, 100% hydration | `Recipe.starterShare` |
| Crunchy semolina | 10% of flour | `newYorkCrunchy.thirdFlourShare` |
| Crunchy malt | 0.5% of flour | `newYorkCrunchy.malt` |
| Live-fire sugar cap | 0.5% | `Oven.liveFireSugarCap` |
| Live-fire stone target | 550–600°F for New York | bake steps text |

The live-fire targets in particular are reasoning from how the two kinds of oven transfer heat,
not from measurement. Step 7 of the New York pizza-oven method is the real instruction: if the
top colors before the base sets, the dome is still too hot.
