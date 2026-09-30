import SwiftUI
import SwiftData

struct AlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Query(sort: \AlertRule.createdAt, order: .reverse) private var rules: [AlertRule]
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if rules.isEmpty {
                    emptyState
                } else {
                    List {
                        if !store.isPro {
                            Section {
                                Text("\(5 - rules.count) of 5 free alerts remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            ForEach(rules, id: \.persistentModelID) { rule in
                                alertRow(rule)
                            }
                            .onDelete(perform: deleteRules)
                        }
                    }
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color.cardGold)
                    }
                    .accessibilityLabel("Upgrade to Pro")
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No price alerts yet").font(.title3.bold())
            Text("Open a saved card in your Binder and add an alert to get notified when its price moves.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func alertRow(_ rule: AlertRule) -> some View {
        HStack {
            Image(systemName: rule.above ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(rule.above ? Color.mintAccent : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.cardName.isEmpty ? rule.cardNumber : rule.cardName)
                    .font(.subheadline.bold())
                Text("\(rule.above ? "Above" : "Below") \(BinderView.dollarString(cents: rule.thresholdCents)) · \(rule.cardNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let last = rule.lastTriggeredAt {
                    Text("Last triggered \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: {
                    rule.isEnabled = $0
                    try? modelContext.save()
                }
            ))
            .labelsHidden()
        }
        .accessibilityElement(children: .combine)
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
        try? modelContext.save()
    }
}
