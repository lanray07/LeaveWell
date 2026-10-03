import Foundation
import StoreKit
import Observation

/// Supply real App Store Connect product identifiers before enabling a paywall.
/// The local edition does not restrict access to existing evidence or export.
@MainActor @Observable
final class PurchaseService {
    private(set) var products: [Product] = []
    private(set) var ownedProductIDs: Set<String> = []
    private let productIDs: Set<String>
    private var listener: Task<Void, Never>?
    init(productIDs: Set<String>) {
        self.productIDs = productIDs
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result, self.productIDs.contains(transaction.productID) else { continue }
                await self.refreshEntitlements(); await transaction.finish()
            }
        }
    }
    deinit { listener?.cancel() }
    func load() async throws {
        products = try await Product.products(for: Array(productIDs)); await refreshEntitlements()
    }
    func purchase(_ product: Product) async throws {
        guard productIDs.contains(product.id) else { return }
        switch try await product.purchase() {
        case .success(.verified(let transaction)): await refreshEntitlements(); await transaction.finish()
        case .success(.unverified): throw PurchaseError.unverified
        case .pending, .userCancelled: break
        @unknown default: break
        }
    }
    func restore() async throws { try await AppStore.sync(); await refreshEntitlements() }
    private func refreshEntitlements() async {
        var verified: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, productIDs.contains(transaction.productID), transaction.revocationDate == nil { verified.insert(transaction.productID) }
        }
        ownedProductIDs = verified
    }
}
enum PurchaseError: LocalizedError {
    case unverified
    var errorDescription: String? { L("The purchase could not be verified. Please try restoring purchases.") }
}
