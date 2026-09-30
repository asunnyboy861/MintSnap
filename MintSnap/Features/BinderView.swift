import SwiftUI
import SwiftData

struct BinderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardRecord.addedAt, order: .reverse) private var records: [CardRecord]
    @State private var showSettings = false
    @State private var showInsights = false
    @State private var insightText: String?
    @State private var isLoadingInsights = false
    @State private var exportURL: URL?
    @State private var showExporter = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard
                            assetCurve
                            exportRow
                            binderGrid
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Binder")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadInsights()
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(records.isEmpty || isLoadingInsights)
                    .accessibilityLabel("Collection insights")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showInsights) {
                insightsSheet
            }
            .sheet(isPresented: $showExporter) {
                if let exportURL {
                    ShareLink(item: exportURL)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Your binder is empty").font(.title3.bold())
            Text("Scan a card and save it to start tracking your collection's value.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var totalCents: Int {
        records.reduce(0) { $0 + $1.currentPriceCents }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total Collection Value")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.dollarString(cents: totalCents))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.mintAccent)
            Text("\(records.count) cards")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var weeklyBuckets: [(week: Date, cents: Int)] {
        let calendar = Calendar.current
        var byWeek: [Date: Int] = [:]
        for record in records {
            let week = calendar.dateInterval(of: .weekOfYear, for: record.addedAt)?.start ?? record.addedAt
            byWeek[week, default: 0] += record.currentPriceCents
        }
        return byWeek.sorted { $0.key < $1.key }.map { (week: $0.key, cents: $0.value) }
    }

    private var assetCurve: some View {
        let buckets = weeklyBuckets
        return VStack(alignment: .leading, spacing: 8) {
            Text("Asset Curve")
                .font(.subheadline.bold())
            if buckets.count < 2 {
                Text("Save cards over multiple weeks to see your collection trend.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                Canvas { context, size in
                    var cumulative: [CGFloat] = []
                    var running: CGFloat = 0
                    for bucket in buckets {
                        running += CGFloat(bucket.cents)
                        cumulative.append(running)
                    }
                    let maxValue = max(running, 1)
                    let stepX = size.width / CGFloat(max(cumulative.count - 1, 1))
                    var points: [CGPoint] = []
                    for (index, value) in cumulative.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = size.height * (1 - value / maxValue)
                        points.append(CGPoint(x: x, y: y))
                    }
                    var path = Path()
                    path.addLines(points)
                    context.stroke(path, with: .color(Color.mintAccent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    var fill = path
                    fill.addLine(to: CGPoint(x: size.width, y: size.height))
                    fill.addLine(to: CGPoint(x: 0, y: size.height))
                    fill.closeSubpath()
                    context.fill(fill, with: .color(Color.mintAccent.opacity(0.15)))
                }
                .frame(height: 80)
                .accessibilityLabel("Collection value trend chart")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var exportRow: some View {
        HStack(spacing: 10) {
            Button {
                exportCSV()
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button {
                exportJSON()
            } label: {
                Label("Export JSON", systemImage: "curlybraces.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var binderGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(records, id: \.persistentModelID) { record in
                NavigationLink {
                    CardDetailView(record: record)
                } label: {
                    BinderCardCell(record: record)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private var insightsSheet: some View {
        NavigationStack {
            ScrollView {
                if isLoadingInsights {
                    ProgressView("Thinking…")
                        .padding(48)
                } else if let insightText {
                    Text(insightText)
                        .font(.body)
                        .padding()
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showInsights = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func loadInsights() {
        showInsights = true
        isLoadingInsights = true
        let stats = CollectionStats(from: records)
        Task {
            let text = await InsightsService.pulseSummary(for: stats)
            insightText = text
            isLoadingInsights = false
        }
    }

    private func exportCSV() {
        exportURL = BinderExport.csv(records)
        showExporter = exportURL != nil
    }

    private func exportJSON() {
        exportURL = BinderExport.json(records)
        showExporter = exportURL != nil
    }

    nonisolated static func dollarString(cents: Int) -> String {
        let value = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

struct BinderCardCell: View {
    let record: CardRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cardImage
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(record.name.isEmpty ? "Unknown Card" : record.name)
                .font(.caption.bold())
                .lineLimit(1)
            Text(BinderView.dollarString(cents: record.currentPriceCents))
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(Color.mintAccent)
            HStack(spacing: 4) {
                Text(record.healthLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(healthColor.opacity(0.18), in: Capsule())
                if record.certVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.mintAccent)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.name), \(BinderView.dollarString(cents: record.currentPriceCents)), confidence \(record.healthLabel)")
    }

    private var healthColor: Color {
        switch record.healthLabel {
        case "HIGH": return Color.mintAccent
        case "MED": return .orange
        default: return .red
        }
    }

    @ViewBuilder
    private var cardImage: some View {
        if let data = record.imageData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let urlString = record.officialImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store
    @Query private var rules: [AlertRule]
    let record: CardRecord
    @State private var showCert = false
    @State private var showAddAlert = false
    @State private var thresholdText = ""
    @State private var isAbove = true
    @State private var alertError: String?

    private var freeAlertsRemaining: Int {
        max(0, 5 - rules.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardImage
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.name.isEmpty ? "Unknown Card" : record.name)
                        .font(.title2.bold())
                    Text([record.setName, record.cardNumber].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if record.isGraded {
                        Label("\(record.grader ?? "Graded") \(record.grade ?? "")", systemImage: "seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.mintAccent)
                    }
                    if record.certVerified {
                        Label("Cert Verified", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.mintAccent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                priceSection

                if record.isGraded && !record.certVerified {
                    Button {
                        showCert = true
                    } label: {
                        Label("Verify Cert", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                alertSection

                Button(role: .destructive) {
                    deleteCard()
                } label: {
                    Label("Remove from Binder", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Card Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCert) {
            CertVerifyView(
                grader: record.grader ?? "",
                certNumber: record.certNumber ?? ""
            ) {
                record.certVerified = true
                try? modelContext.save()
            }
        }
    }

    private var cardImage: some View {
        Group {
            if let data = record.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let urlString = record.officialImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Card image")
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(BinderView.dollarString(cents: record.currentPriceCents))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.mintAccent)
            HStack(spacing: 8) {
                Text(record.activeTier).font(.caption)
                Text("· \(record.priceSource)").font(.caption)
                Text(healthBadge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(healthColor.opacity(0.18), in: Capsule())
            }
            .foregroundStyle(.secondary)
            if !record.healthReason.isEmpty {
                Text(record.healthReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Updated \(record.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var healthBadge: String {
        record.healthLabel + (Date().timeIntervalSince(record.fetchedAt) > 7 * 86400 ? " · stale" : "")
    }

    private var healthColor: Color {
        switch record.healthLabel {
        case "HIGH": return Color.mintAccent
        case "MED": return .orange
        default: return .red
        }
    }

    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Price Alert")
                .font(.subheadline.bold())
            HStack {
                TextField("Threshold ($)", text: $thresholdText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $isAbove) {
                    Text("Above").tag(true)
                    Text("Below").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                Button("Add") { addAlert() }
                .buttonStyle(.borderedProminent)
            }
            if let alertError {
                Text(alertError).font(.caption).foregroundStyle(.red)
            }
            let cardRules = rules.filter { $0.cardNumber == record.cardNumber && $0.cardName == record.name }
            ForEach(cardRules, id: \.persistentModelID) { rule in
                HStack {
                    Image(systemName: rule.above ? "arrow.up.circle" : "arrow.down.circle")
                        .foregroundStyle(Color.mintAccent)
                    Text("\(rule.above ? "Above" : "Below") \(BinderView.dollarString(cents: rule.thresholdCents))")
                        .font(.caption)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { rule.isEnabled = $0; try? modelContext.save() }
                    ))
                    .labelsHidden()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func addAlert() {
        if !store.isPro && freeAlertsRemaining == 0 {
            alertError = "Free tier includes 5 alerts. Upgrade to Pro for unlimited alerts."
            return
        }
        let cleaned = thresholdText.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let dollars = Double(cleaned), dollars > 0 else {
            alertError = "Enter a valid price."
            return
        }
        let rule = AlertRule(
            cardName: record.name,
            cardNumber: record.cardNumber,
            thresholdCents: Int(dollars * 100),
            above: isAbove
        )
        modelContext.insert(rule)
        try? modelContext.save()
        thresholdText = ""
        alertError = nil
        Task { await AlertEngine.shared.requestNotificationPermission() }
    }

    private func deleteCard() {
        modelContext.delete(record)
        try? modelContext.save()
        dismiss()
    }
}

enum BinderExport {
    static func csv(_ records: [CardRecord]) -> URL? {
        var rows = ["Name,Set,Number,Tier,Price,Health,Source,Grader,Grade,Cert,Verified,Added"]
        for record in records {
            let fields = [
                record.name, record.setName, record.cardNumber, record.activeTier,
                String(format: "%.2f", Double(record.currentPriceCents) / 100),
                record.healthLabel, record.priceSource, record.grader ?? "",
                record.grade ?? "", record.certNumber ?? "",
                record.certVerified ? "yes" : "no",
                ISO8601DateFormatter().string(from: record.addedAt)
            ]
            rows.append(fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }
        let text = rows.joined(separator: "\n")
        return write(text, name: "MintSnapBinder.csv")
    }

    static func json(_ records: [CardRecord]) -> URL? {
        struct Item: Codable {
            var name: String
            var set: String
            var number: String
            var tier: String
            var priceUSD: Double
            var health: String
            var source: String
            var grader: String?
            var grade: String?
            var cert: String?
            var verified: Bool
            var addedAt: Date
        }
        let items = records.map {
            Item(
                name: $0.name, set: $0.setName, number: $0.cardNumber, tier: $0.activeTier,
                priceUSD: Double($0.currentPriceCents) / 100, health: $0.healthLabel,
                source: $0.priceSource, grader: $0.grader, grade: $0.grade,
                cert: $0.certNumber, verified: $0.certVerified, addedAt: $0.addedAt
            )
        }
        guard let data = try? JSONEncoder().encode(items) else { return nil }
        let text = String(data: data, encoding: .utf8) ?? ""
        return write(text, name: "MintSnapBinder.json")
    }

    private static func write(_ text: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

struct CollectionStats {
    var cardCount: Int
    var totalValueCents: Int
    var gradedCount: Int
    var topCardName: String
    var topCardCents: Int

    init(from records: [CardRecord]) {
        cardCount = records.count
        totalValueCents = records.reduce(0) { $0 + $1.currentPriceCents }
        gradedCount = records.filter(\.isGraded).count
        if let top = records.max(by: { $0.currentPriceCents < $1.currentPriceCents }) {
            topCardName = top.name
            topCardCents = top.currentPriceCents
        } else {
            topCardName = ""
            topCardCents = 0
        }
    }
}
