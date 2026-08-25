import Foundation
import StoreKit

/// StoreKit 2 entitlement checks for Lune Premium.
@MainActor
@Observable
final class PremiumService {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var monthlyProduct: Product?
    private(set) var hasEntitlement = false

    private var updatesTask: Task<Void, Never>?

    func start() async {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                if Task.isCancelled { break }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: [LunePremium.monthlyProductID])
            monthlyProduct = products.first
            loadState = .ready
        } catch {
            loadState = .failed("Couldn’t load subscription options.")
            monthlyProduct = nil
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == LunePremium.monthlyProductID,
               transaction.revocationDate == nil
            {
                entitled = true
                break
            }
        }
        hasEntitlement = entitled
    }

    func purchaseMonthly() async throws {
        guard let product = monthlyProduct else {
            throw PremiumError.productUnavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PremiumError.verificationFailed
            }
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}

enum PremiumError: LocalizedError {
    case productUnavailable
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "Premium isn’t available right now. Try again later."
        case .verificationFailed:
            "Purchase couldn’t be verified."
        }
    }
}
