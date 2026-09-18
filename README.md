# Proofed — pizza dough calculator for iOS

Native SwiftUI port of a web dough calculator. Pick size, count, thickness and gluten-free;
get ball weight, ingredient grams, baker's percentages, a tip, and step-by-step instructions.

## 1. Executive summary
Offline, single-screen iOS app. No network, no accounts, no analytics. All math is local and
unit-tested against values produced by the reference JavaScript formulas.

## 2. Architecture
```
+---------------------------------------------+
| ProofedApp (@main)                          |
|   +-------------------------------------+   |
|   | CalculatorView (SwiftUI)            |   |
|   |  @AppStorage inputs --> DoughInput  |   |
|   |          |                          |   |
|   |          v                          |   |
|   |  DoughCalculator.calculate() (pure) |   |
|   |          |                          |   |
|   |          v                          |   |
|   |  DoughResult --> BallHero, Stats,   |   |
|   |   TipBanner, IngredientTable, Steps |   |
|   |          |                          |   |
|   |          v                          |   |
|   |  ShareLink(shareText) -> share sheet|   |
|   +-------------------------------------+   |
+---------------------------------------------+
```

## 3. Data flows
```
slider/picker/toggle
      |
      v
UserDefaults (@AppStorage) --persists--> next launch
      |
      v
DoughInput --> DoughCalculator --> DoughResult --> UI
                                        |
                                        v
                          plain-text recipe --> iOS share sheet
                          (Messages, Notes, Mail, Print, Copy)
```
Nothing leaves the device unless the user shares it.

## 4. API routes
None. The app has no server or network calls.

## 5. Database / storage
UserDefaults keys only:

| Key          | Type   | Default   |
|--------------|--------|-----------|
| sizeInches   | Int    | 16        |
| count        | Int    | 6         |
| thickness    | String | "regular" |
| glutenFree   | Bool   | false     |

## 6. External dependencies
None. SwiftUI/UIKit/Foundation only. Build tooling: Xcode 15+ and (optionally) XcodeGen.

## 7. Key files
| File | Purpose |
|------|---------|
| `Proofed/Model/DoughCalculator.swift` | All formulas, tips, steps, share text |
| `Proofed/Views/CalculatorView.swift`  | Screen and components |
| `Proofed/Views/Theme.swift`           | Colors (light/dark) |
| `ProofedTests/DoughCalculatorTests.swift` | Golden-value tests |
| `project.yml` | XcodeGen spec that generates `Proofed.xcodeproj` |

### Formula
Every style scales the same way; only the constants differ (see `Recipe` in DoughCalculator.swift,
mirrored by `RECIPES` in docs/index.html):
```
flour = baseFlour * (size/refSize)^2 * (count/refCount) * (thicknessFactor/2.11)
ball  = flour * doughRatio / count
factor = thin 1.8 | regular 2.11 | thick 2.75

              baseFlour  ref       hydration  yeast   salt    sugar   fat    doughRatio
classic       1705.19 g  6 x 16"   62%        0.4%    2.5%    2%      3.3%   1.6890
classic GF    1998 g     6 x 16"   80%        0.4%    2.5%    2%      3.3%   1.6890
neapolitan    232 g      2 x 11"   73.28%     0.17%   3.45%   0.86%   none   1.7776
new york      900 g      4 x 15"   64%        0.56%   3.44%   1.56%   3%     1.7256
tavern        300 g      2 x 12"   50%        0.67%   2.33%   2.33%   10%    1.6533
```
New York blends flour: 90% bread, 10% whole wheat (`secondFlourShare`). Neapolitan has no oil,
and zero-weight rows are dropped from the table.

Classic constants come from the reference site. Tavern comes from a published Chicago
tavern-style recipe (300 g flour, 150 g water, 30 g oil/butter, 7 g sugar, 7 g salt,
1-5 g instant yeast); 2 g yeast and "two 12in pizzas per batch" are our reading of it.
Rounding mirrors JS `Math.round` (halves up) and yeast uses one decimal.

## 8. Common gotchas
- Reference sizes are our reading of each source's yield: Neapolitan says two 10-12" pies
  (we use 11"), New York says four 14-16" pies (we use 15"). New York's own 2 x 19" option is
  not area-consistent with its 4 x 15" option, so big-pie numbers differ slightly from the source.
- Only the classic dough has gluten-free numbers; other styles ignore the gluten-free toggle (no GF numbers exist for it), and the UI hides
  the toggle for that style.
- Tavern's "two 12in pizzas per 300 g flour" is an assumption, not from the source recipe.
  Change `baseFlour`/`refCount` in one place if your pans say otherwise.
- Classic only: ball weight does not equal the sum of ingredients. It uses a fixed 1.689× dough-to-flour
  ratio, while ingredients add up to 1.702× (regular) or 1.882× (GF). GF balls are therefore
  about 10% lighter than the dough you actually make. This is intentional parity with the web tool.
- The web page's static HTML shows 425 / 1708 / 1059 as placeholders; its JavaScript replaces
  them with 480 / 1705 / 1057. Trust the tests, not the placeholder text.
- If the reference site changes its constants, update `DoughCalculator` and the golden values.
- `.xcodeproj` is git-ignored because XcodeGen regenerates it. If you create the project by
  hand in Xcode instead, remove that line from `.gitignore`.
- Signing: set your team in `project.yml` (DEVELOPMENT_TEAM) or in Xcode, and change
  `com.example.proofed` to a bundle ID you own.

## 9. Common operations
Setup (Mac):
```
brew install xcodegen
git clone <your repo> && cd proofed
xcodegen generate
open Proofed.xcodeproj
```
Test: `xcodebuild test -scheme Proofed -destination 'platform=iOS Simulator,name=iPhone 16'`
(or Cmd+U in Xcode).
Run on phone: plug in iPhone, select it as destination, Cmd+R (free Apple ID works for 7-day installs).
TestFlight: Product > Archive > Distribute App > App Store Connect (requires paid developer account).
Debug: SwiftUI previews in CalculatorView.swift; breakpoints in `DoughCalculator.calculate`.
Without XcodeGen: File > New > Project > iOS App (SwiftUI) named Proofed, delete its generated
ContentView/App files, drag in `Proofed/` sources, add a Unit Testing target and drag in `ProofedTests/`.

---

## Web app (GitHub Pages)
`docs/` is a standalone home-screen web app using the same formulas as the Swift model
(verified against the same golden values). Files: `index.html` (all HTML/CSS/JS),
`manifest.json`, `sw.js` (offline cache), `icons/`.

Publish:
```
git remote add origin git@github.com:<you>/proofed.git
git push -u origin master
```
Then GitHub > repo > Settings > Pages > Source: "Deploy from a branch", branch `master`, folder `/docs`.
Live at `https://<you>.github.io/proofed/` after a minute or two.

Install on iPhone: open that URL in Safari > Share > Add to Home Screen.
After updating files, bump `CACHE` in `sw.js` or the phone keeps serving the old version.

## SideStore
`scripts/build-ipa.sh` produces `Proofed.ipa` from the Xcode project (unsigned; SideStore
re-signs with your Apple ID). Plug in the phone, run it from the repo root, then AirDrop the
.ipa and open it in SideStore.
