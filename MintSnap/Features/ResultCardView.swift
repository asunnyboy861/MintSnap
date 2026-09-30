import SwiftUI
import SwiftData

struct ResultCardView: View {
    @State private var session: ScanViewModel.ScanSession
    @State private var priceResult: PriceResult?
    @State private var isLoadingPrice = false
    @State private var showPaywall = false
    let cloudNotice: String?
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Environment(QuotaService.self) private var quota
    @State private var displayedPrice: Double = 0
    @State private var showCorrection = false
    @State private var showCertVerify = false
    @State private var showROI = false
    @State private var selectedTier: GradeTier = .ungraded
    @State private var saved = false
    @State private var certVerified = false

    init(
        session: ScanViewModel.ScanSession,
        cloudNotice: String?,
        onDismiss: @escaping () -> Void
    ) {
        _session = State(initialValue: session)
        self.cloudNotice = cloudNotice
        self.onDismiss = onDismiss
    }

    private var identity: CardIdentity { session.localIdentity }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let notice = cloudNotice {
                    Text(notice)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.mintAccent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.mintAccent)
                }

                cardHeader

                priceSection

                tierSlider

                healthSection

                actionButtons

                if !store.isPro {
                    lockedFeaturesNotice
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            animatePrice()
            Task { await loadPrice() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showCorrection) {
            CorrectionView(session: session) { corrected in
                if let corrected {
                    session = corrected
                    Task {
                        priceResult = nil
                        await loadPrice()
                    }
                } else {
                    onDismiss()
                }
                showCorrection = false
            }
        }
        .sheet(isPresented: $showCertVerify) {
            CertVerifyView(
                grader: identity.grader ?? "",
                certNumber: identity.certNumber ?? ""
            ) {
                certVerified = true
            }
        }
        .sheet(isPresented: $showROI) {
            ROICalculatorView(rawPriceCents: currentPriceCents ?? 0, tiered: priceResult?.tiered)
        }
    }

    private func loadPrice() async {
        isLoadingPrice = true
        let query = [session.localIdentity.cardName, session.localIdentity.cardNumber]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        priceResult = await PriceChartingService.shared.fetchTieredPrice(query: query)
        if let tier = GradeTier(rawValue: session.localIdentity.grade.map { "PSA \($0)" } ?? "") {
            selectedTier = tier
        }
        isLoadingPrice = false
    }

    private func animatePrice() {
        guard let cents = currentPriceCents else { return }
        displayedPrice = 0
        withAnimation(.easeOut(duration: 0.4)) {
            displayedPrice = Double(cents) / 100.0
        }
    }

    private var currentPriceCents: Int? {
        priceResult?.tiered?.value(for: selectedTier) ?? priceResult?.tiered?.ungraded
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            officialImage
                .frame(width: 110, height: 154)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 6) {
                Text(identity.cardName.isEmpty ? "Unknown Card" : identity.cardName)
                    .font(.headline)
                    .lineLimit(2)
                Text([identity.setName, identity.cardNumber].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if identity.isReverseHolo {
                    Label("Reverse Holo", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color.cardGold)
                }
                if identity.isGraded {
                    Label("\(identity.grader ?? "Graded") \(identity.grade ?? "")", systemImage: "seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.mintAccent)
                }
                HStack(spacing: 8) {
                    Text(confidenceText)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mintAccent.opacity(0.15), in: Capsule())
                    Button {
                        showCorrection = true
                    } label: {
                        Text("Not this card?")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(identity.cardName), \(identity.setName), confidence \(confidenceText)")
    }

    private var officialImage: some View {
        Group {
            if let urlString = officialImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage
                    default:
                        placeholderImage
                    }
                }
            } else if let data = session.croppedImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
            } else {
                placeholderImage
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Official card image for verification")
    }

    private var officialImageURL: String? {
        if let url = priceResult?.officialImageURL { return url }
        if let path = priceResult == nil ? nil : session.candidates.first?.image {
            return TCGdexService.shared.imageURL(from: path)
        }
        return session.candidates.first?.image.map { TCGdexService.shared.imageURL(from: $0) ?? "" }
    }

    private var placeholderImage: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private var confidenceText: String {
        session.confidence >= 0.9 ? "HIGH confidence" : "Verify match"
    }

    private var priceSection: some View {
        VStack(spacing: 4) {
            if isLoadingPrice {
                ProgressView()
                Text("Fetching market price…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let cents = currentPriceCents {
                Text("$\(displayedPrice, specifier: "%.2f")")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.mintAccent)
                    .contentTransition(.numericText())
                Text("\(selectedTier.rawValue) · \(priceResult?.source ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No price data")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                Text("Search manually in Binder to set a value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var tierSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grade Tiers")
                .font(.subheadline.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GradeTier.allCases) { tier in
                        let price = priceResult?.tiered?.value(for: tier)
                        tierChip(tier: tier, priceCents: price)
                    }
                }
            }
            if !store.isPro {
                Text("Full graded pricing with Pro")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func tierChip(tier: GradeTier, priceCents: Int?) -> some View {
        let locked = !store.isPro && tier != .ungraded
        let priceText = locked ? "•••" : (priceCents.map { String(format: "$%.2f", Double($0) / 100) } ?? "—")
        return Button {
            guard !locked else { return }
            selectedTier = tier
            animatePrice()
        } label: {
            VStack(spacing: 2) {
                Text(tier.shortLabel)
                    .font(.caption.bold())
                Text(priceText)
                    .font(.caption2)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selectedTier == tier ? Color.mintAccent : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(selectedTier == tier ? .white : .primary)
        }
        .disabled(locked)
        .accessibilityLabel("\(tier.rawValue) price \(locked ? "locked" : priceText)")
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Price Health")
                    .font(.subheadline.bold())
                Spacer()
                if let health = priceResult?.health {
                    Text(health.label.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(healthColor(health.label).opacity(0.2), in: Capsule())
                        .foregroundStyle(healthColor(health.label))
                }
            }
            if let health = priceResult?.health {
                Text(health.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let source = priceResult?.source, source != "None" {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Source: \(source) · \(Date.now.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func healthColor(_ label: HealthLabel) -> Color {
        switch label {
        case .high: return Color.mintAccent
        case .medium: return .orange
        case .low: return .red
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                saveCard()
            } label: {
                Label(saved ? "Saved to Binder" : "Save to Binder", systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mintAccent)
            .disabled(saved)

            HStack(spacing: 10) {
                Button {
                    showCertVerify = true
                } label: {
                    Label("Verify Cert", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!identity.isGraded)

                Button {
                    showROI = true
                } label: {
                    Label("Grade ROI", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(currentPriceCents == nil)
            }
        }
    }

    private var lockedFeaturesNotice: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("Save, graded tiers and alerts need Pro")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func saveCard() {
        if !store.isPro && quota.freeScansRemaining == 0 {
            showPaywall = true
            return
        }
        guard let priceCents = currentPriceCents else { return }
        if priceResult?.source != "cloud" {
            quota.consumeOnDeviceScan()
        }
        let record = CardRecord(
            identity: identity,
            imageData: session.croppedImageData,
            officialImageURL: officialImageURL,
            tier: selectedTier,
            priceCents: priceCents,
            health: priceResult?.health.label ?? .low,
            reason: priceResult?.health.reason ?? "",
            source: priceResult?.source ?? "None"
        )
        record.certVerified = certVerified && identity.isGraded
        modelContext.insert(record)
        try? modelContext.save()
        saved = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            onDismiss()
        }
    }
}

struct CorrectionView: View {
    let session: ScanViewModel.ScanSession
    let onPick: (ScanViewModel.ScanSession?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Top matches — tap to correct") {
                    ForEach(session.candidates.prefix(3), id: \.id) { card in
                        Button {
                            var identity = session.localIdentity
                            identity.cardName = card.name
                            onPick(sessionWith(identity: identity))
                        } label: {
                            HStack {
                                cardImage(for: card)
                                    .frame(width: 44, height: 62)
                                    .background(Color(.tertiarySystemFill))
                                    .cornerRadius(6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name).font(.subheadline)
                                    Text(card.set?.name ?? card.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        onPick(nil)
                    } label: {
                        Label("Scan again", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Correct Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onPick(nil) }
                }
            }
        }
    }

    private func cardImage(for card: TCGdexService.TCgdexCard) -> some View {
        Group {
            if let path = card.image, let url = URL(string: TCGdexService.shared.imageURL(from: path) ?? "") {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sessionWith(identity: CardIdentity) -> ScanViewModel.ScanSession {
        ScanViewModel.ScanSession(
            croppedImageData: session.croppedImageData,
            localIdentity: identity,
            confidence: session.confidence,
            candidates: session.candidates
        )
    }
}
