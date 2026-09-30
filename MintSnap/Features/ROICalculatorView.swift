import SwiftUI

struct ROICalculatorView: View {
    let rawPriceCents: Int
    var tiered: TieredPrice?

    @State private var feeText = "25.00"
    @State private var shippingText = "5.00"
    @State private var expectedTier: GradeTier = .psa10
    @State private var expectedPriceText = ""

    private var feeCents: Int? {
        Int((Double(feeText) ?? 0) * 100)
    }

    private var shippingCents: Int? {
        Int((Double(shippingText) ?? 0) * 100)
    }

    private var expectedTierPriceCents: Int? {
        if let manual = Double(expectedPriceText), manual > 0 {
            return Int(manual * 100)
        }
        return tiered?.value(for: expectedTier)
    }

    private var calculation: GradeROICalculator? {
        guard let feeCents, let shippingCents, let expectedTierPriceCents else { return nil }
        return GradeROICalculator(
            rawPriceCents: rawPriceCents,
            gradingFeeCents: feeCents,
            shippingCents: shippingCents,
            expectedTierPriceCents: expectedTierPriceCents
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    inputSection
                    if let calc = calculation {
                        verdictSection(calc)
                    } else {
                        Text("Enter grading fee and expected price to calculate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Grading ROI")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raw card value").font(.subheadline.bold())
            Text(BinderView.dollarString(cents: rawPriceCents))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(Color.mintAccent)

            Text("Grading fee").font(.subheadline.bold())
            HStack(spacing: 8) {
                TextField("Fee", text: $feeText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                feePreset("PSA $25", value: "25.00")
                feePreset("BGS", value: "40.00")
                feePreset("SGC", value: "22.00")
            }

            Text("Shipping (round trip)").font(.subheadline.bold())
            TextField("Shipping", text: $shippingText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Text("Expected grade").font(.subheadline.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([GradeTier.g7, .g8, .g9, .g95, .psa10]) { tier in
                        tierChip(tier)
                    }
                }
            }

            Text("Expected tier price").font(.subheadline.bold())
            TextField("Leave empty to use market price", text: $expectedPriceText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            if expectedPriceText.isEmpty, let auto = expectedTierPriceCents {
                Text("Market estimate: \(BinderView.dollarString(cents: auto))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func feePreset(_ label: String, value: String) -> some View {
        Button {
            feeText = value
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.mintAccent.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set grading fee to \(label)")
    }

    private func tierChip(_ tier: GradeTier) -> some View {
        let selected = expectedTier == tier
        return Button {
            expectedTier = tier
        } label: {
            VStack(spacing: 2) {
                Text(tier.shortLabel).font(.caption.bold())
                if let price = tiered?.value(for: tier) {
                    Text(BinderView.dollarString(cents: price))
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? Color.mintAccent : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expected tier \(tier.rawValue)")
    }

    private func verdictSection(_ calc: GradeROICalculator) -> some View {
        VStack(spacing: 14) {
            Label(calc.verdict, systemImage: calc.isWorthIt ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(calc.isWorthIt ? Color.mintAccent : .red)
                .padding(.top, 8)

            HStack {
                Text("Grading cost")
                Spacer()
                Text(BinderView.dollarString(cents: calc.totalCostCents)).monospacedDigit()
            }
            HStack {
                Text("Expected sale")
                Spacer()
                Text(BinderView.dollarString(cents: calc.expectedTierPriceCents)).monospacedDigit()
            }
            Divider()
            HStack {
                Text("Net profit").bold()
                Spacer()
                Text(BinderView.dollarString(cents: calc.netProfitCents))
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(calc.netProfitCents >= 0 ? Color.mintAccent : .red)
            }

            Text(calc.isWorthIt
                 ? "Expected profit clears the $50 worth-it rule after fees and shipping."
                 : "Profit doesn't clear the $50 worth-it rule. Consider selling raw.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
