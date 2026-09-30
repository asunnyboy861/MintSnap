import Foundation
import StoreKit

@Observable
final class StoreService {
    static let shared = StoreService()

    static let proMonthlyID = "com.mintsnap.pro.monthly"
    static let proYearlyID = "com.mintsnap.pro.yearly"
    static let boost100ID = "com.mintsnap.boost.cloud100"

    private(set) var isPro: Bool = false
    private(set) var activeProID: String?
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var lastPurchaseError: String?

    private var transactionListener: Task<Void, Never>?
    private let proIDs = [StoreService.proMonthlyID, StoreService.proYearlyID]

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.proMonthlyID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.proYearlyID } }
    var boostProduct: Product? { products.first { $0.id == Self.boost100ID } }

    func loadProducts() async {
        isLoading = true
        loadError = nil
        do {
            products = try await Product.products(for: proIDs + [Self.boost100ID])
            if products.isEmpty {
                loadError = "Store products unavailable. Check App Store Connect configuration."
            }
        } catch {
            loadError = "Unable to load purchase options."
        }
        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        lastPurchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    if product.id == Self.boost100ID {
                        QuotaService.shared.addCloudCredits(100)
                    } else {
                        AlertEngine.shared.scheduleTrialEndNudge()
                    }
                    return true
                } else {
                    lastPurchaseError = "Purchase verification failed."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastPurchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        return false
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastPurchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var pro = false
        var activeID: String?
        for id in proIDs {
            if let result = await Transaction.currentEntitlement(for: id),
               case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                pro = true
                activeID = id
                break
            }
        }
        isPro = pro
        activeProID = activeID
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
