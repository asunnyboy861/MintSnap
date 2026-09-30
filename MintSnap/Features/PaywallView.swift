import SwiftUI
import StoreKit

struct PaywallView: View {
    var embedded = false
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !embedded {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Close")
                        }
                        .padding(.horizontal)
                    }

                    header

                    pricingCards

                    Text("We don't sell a lifetime pass because we pay for your AI scans every month — and we'd rather stay honest than go broke.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    legalFooter
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(embedded ? "" : "MintSnap Pro")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if store.products.isEmpty {
                    await store.loadProducts()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.cardGold)
            Text("MintSnap Pro")
                .font(.largeTitle.bold())
            Text("Unlimited on-device scans. Transparent pricing. Cancel anytime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var pricingCards: some View {
        VStack(spacing: 14) {
            if let monthly = store.monthlyProduct {
                subscriptionCard(
                    title: "Pro Monthly",
                    price: monthly.displayPrice,
                    period: "per month",
                    trial: "7-day free trial",
                    product: monthly
                )
            }
            if let yearly = store.yearlyProduct {
                subscriptionCard(
                    title: "Pro Yearly",
                    price: yearly.displayPrice,
                    period: "per year",
                    trial: "7-day free trial · Best value",
                    product: yearly
                )
            }
            if let boost = store.boostProduct {
                boostCard(product: boost)
            }
            if let error = store.loadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let error = store.lastPurchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
    }

    private func subscriptionCard(title: String, price: String, period: String, trial: String, product: Product) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(trial).font(.caption).foregroundStyle(Color.mintAccent)
                }
                Spacer()
                Text(price).font(.title3.bold()).monospacedDigit()
                Text(period).font(.caption).foregroundStyle(.secondary)
            }
            Button {
                Task {
                    _ = await store.purchase(product)
                }
            } label: {
                Text("Subscribe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func boostCard(product: Product) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Boost Pack").font(.headline)
                    Text("100 extra cloud scans · one-time").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice).font(.title3.bold()).monospacedDigit()
            }
            Button {
                Task {
                    _ = await store.purchase(product)
                }
            } label: {
                Text("Buy Boost")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var legalFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://zzoutuo.github.io/MintSnap/privacy.html")!)
                    .font(.caption)
                Link("Terms of Use", destination: URL(string: "https://zzoutuo.github.io/MintSnap/terms.html")!)
                    .font(.caption)
            }
            Text("Payment is charged to your Apple ID account. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Restore Purchases") {
                Task { await store.restorePurchases() }
            }
            .font(.caption)
        }
        .padding(.horizontal)
    }
}
