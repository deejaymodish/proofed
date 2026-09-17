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
```
flour = base * (size/16)^2 * (count/6) * (thicknessFactor/2.11)
  base   = 1509.797685 * 480/425  (≈1705.19 g)  regular
         = 1998 g                                gluten-free
  factor = thin 1.8 | regular 2.11 | thick 2.75
water = flour * (0.62 regular | 0.80 GF)
yeast 0.4%  salt 2.5%  sugar 2%  olive oil 3.3%   (of flour)
ball  = flour * (2550/1509.797685) / count
```
Rounding mirrors JS `Math.round` (halves up) and yeast uses one decimal.

## 8. Common gotchas
- Ball weight does not equal the sum of ingredients. It uses a fixed 1.689× dough-to-flour
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
