import SwiftUI

struct CalculatorView: View {
    // Persist the last settings between launches.
    @AppStorage("sizeInches") private var sizeInches = 16
    @AppStorage("count") private var count = 6
    @AppStorage("thickness") private var thicknessRaw = Thickness.regular.rawValue
    @AppStorage("glutenFree") private var glutenFree = false
    @State private var showSteps = false

    private var input: DoughInput {
        DoughInput(sizeInches: sizeInches.clamped(to: DoughInput.sizeRange),
                   count: count.clamped(to: DoughInput.countRange),
                   thickness: Thickness(rawValue: thicknessRaw) ?? .regular,
                   glutenFree: glutenFree)
    }

    var body: some View {
        let input = self.input
        let result = DoughCalculator.calculate(input)

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BallHero(grams: result.ballGrams, sizeInches: input.sizeInches, summary: result.summary)
                    settings
                    StatsRow(result: result)
                    if let tip = result.tip { TipBanner(tip: tip) }
                    IngredientTable(result: result)
                    stepsSection(result, glutenFree: input.glutenFree)
                }
                .padding()
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle("Dough")
            .toolbar {
                ShareLink(item: DoughCalculator.shareText(input: input, result: result)) {
                    Label("Share recipe", systemImage: "square.and.arrow.up")
                }
            }
        }
        .tint(Theme.basil)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            SliderRow(title: "Pizza size", value: $sizeInches, range: DoughInput.sizeRange, unit: "\"")
            SliderRow(title: "Number of pizzas", value: $count, range: DoughInput.countRange, unit: "")

            VStack(alignment: .leading, spacing: 8) {
                Text("Thickness").font(.subheadline.weight(.semibold))
                Picker("Thickness", selection: $thicknessRaw) {
                    ForEach(Thickness.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $glutenFree) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gluten-free").font(.subheadline.weight(.semibold))
                    Text("Uses GF flour and 80% hydration").font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .sensoryFeedback(.selection, trigger: input)
    }

    private func stepsSection(_ result: DoughResult, glutenFree: Bool) -> some View {
        DisclosureGroup(isExpanded: $showSteps) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(result.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(Theme.basil)
                            .frame(width: 20, alignment: .trailing)
                        Text(step).font(.subheadline)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Text(glutenFree ? "How to make gluten-free dough" : "How to make the dough")
                .font(.headline).foregroundStyle(Theme.steel)
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension Int {
    func clamped(to r: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, r.lowerBound), r.upperBound) }
}

// MARK: - Components

/// The one bold element: a dough ball whose diameter grows with pizza size.
private struct BallHero: View {
    let grams: Int
    let sizeInches: Int
    let summary: String

    var body: some View {
        let span = Double(DoughInput.sizeRange.upperBound - DoughInput.sizeRange.lowerBound)
        let t = Double(sizeInches - DoughInput.sizeRange.lowerBound) / span
        let diameter = 150 + 70 * t

        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.semolina.opacity(0.95), Theme.semolina.opacity(0.7)],
                                         center: .topLeading, startRadius: 10, endRadius: diameter))
                    .frame(width: diameter, height: diameter)
                    .animation(.spring(duration: 0.35), value: sizeInches)
                VStack(spacing: 0) {
                    Text("\(grams)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.snappy, value: grams)
                    Text("grams per ball").font(.caption.weight(.medium))
                }
                .foregroundStyle(Color(hex: 0x2B3036))
            }
            .frame(height: 220)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(grams) grams per dough ball")

            Text(summary).font(.subheadline).foregroundStyle(Theme.muted)
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value)\(unit)").font(.subheadline.monospacedDigit().weight(.bold))
            }
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .accessibilityLabel(title)
                .accessibilityValue("\(value)\(unit)")
        }
    }
}

private struct StatsRow: View {
    let result: DoughResult

    var body: some View {
        HStack(spacing: 10) {
            stat("\(result.flourGrams)", "g flour")
            stat("\(result.waterGrams)", "g water")
            stat("\(result.hydrationPercent)%", "hydration")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.monospacedDigit().weight(.bold)).foregroundStyle(Theme.steel)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct TipBanner: View {
    let tip: Tip
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill").foregroundStyle(Theme.semolina)
            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title).font(.subheadline.weight(.semibold))
                Text(tip.message).font(.subheadline).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Theme.semolina.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct IngredientTable: View {
    let result: DoughResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(result.doughType).font(.headline)
                Spacer()
                Text(result.restNote).font(.caption).foregroundStyle(Theme.basil)
            }
            .padding(.bottom, 10)

            ForEach(result.ingredients) { item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        if let note = item.note {
                            Text(note).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                    Text("\(item.amount) g").font(.body.monospacedDigit().weight(.semibold))
                    Text(item.bakersPercent)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .frame(width: 48, alignment: .trailing)
                }
                .padding(.vertical, 9)
                if item != result.ingredients.last { Divider() }
            }
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { CalculatorView() }
