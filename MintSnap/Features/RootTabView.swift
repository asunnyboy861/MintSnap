import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ScanView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
            BinderView()
                .tabItem { Label("Binder", systemImage: "square.grid.2x2.fill") }
            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell.fill") }
            ProTabView()
                .tabItem { Label("Pro", systemImage: "crown.fill") }
        }
    }
}

struct ProTabView: View {
    @Environment(StoreService.self) private var store
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            if store.isPro {
                ProStatusView()
            } else {
                PaywallView(embedded: true)
            }
        }
    }
}

struct ProStatusView: View {
    @Environment(StoreService.self) private var store
    @Environment(QuotaService.self) private var quota
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.cardGold)
                Text("MintSnap Pro")
                    .font(.title.bold())
                Text("Unlimited on-device scans and monthly cloud AI scans are active.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mintAccent)
                        Text("Unlimited on-device scans")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mintAccent)
                        Text(quota.hasBYOKey
                             ? "Cloud scans via your own API key (unlimited)"
                             : "Cloud AI scans: \(quota.proCloudUsedThisMonth)/\(quota.proCloudLimit) this month")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mintAccent)
                        Text("All graded tiers unlocked")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mintAccent)
                        Text("Unlimited price alerts")
                    }
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.subheadline.bold())
            }
            .padding()
        }
        .navigationTitle("Pro")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
