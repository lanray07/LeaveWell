import Foundation
import StoreKit
import Observation

enum PlusPlan {
    static let monthly = "com.LeaveWell.app.plus.monthly"
    static let annual = "com.LeaveWell.app.plus.annual"
    static let productIDs: Set<String> = [monthly, annual]
    static let privacyURL = URL(string: "https://github.com/lanray07/LeaveWell/blob/main/marketing/privacy.md")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

@MainActor @Observable
final class PurchaseService {
    private(set) var products: [Product] = []
    private(set) var ownedProductIDs: Set<String> = []
    private(set) var loading = false
    private(set) var purchasing = false
    private(set) var message: String?
    private(set) var errorMessage: String?
    private var expirationDates: [String: Date] = [:]
    @ObservationIgnored private var listener: Task<Void, Never>?
    var hasPlus: Bool { expirationDates.values.contains { $0 > Date() } }
    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result, PlusPlan.productIDs.contains(transaction.productID) else { continue }
                await self.refreshEntitlements(); await transaction.finish()
            }
        }
    }
    deinit { listener?.cancel() }
    func load() async {
        guard !loading else { return }
        loading = true; errorMessage = nil
        defer { loading = false }
        // Refresh cached verified transactions even when the storefront is offline.
        await refreshEntitlements()
        do {
            products = try await Product.products(for: Array(PlusPlan.productIDs))
                .filter { $0.type == .autoRenewable }
                .sorted { $0.id == PlusPlan.monthly && $1.id != PlusPlan.monthly }
            if products.isEmpty { errorMessage = L("Plans are temporarily unavailable. Please try again later. Your records remain available.") }
        } catch is CancellationError { }
        catch { errorMessage = L("Unable to load subscription prices. Check your connection and try again.") }
    }
    func purchase(_ product: Product) async {
        guard !purchasing, PlusPlan.productIDs.contains(product.id), product.type == .autoRenewable else { return }
        purchasing = true; message = nil; errorMessage = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                guard PlusPlan.productIDs.contains(transaction.productID) else { throw PurchaseError.unverified }
                await refreshEntitlements(); await transaction.finish()
                message = hasPlus ? L("LeaveWell Plus is ready. You can now create PDF evidence reports.") : L("No active LeaveWell Plus subscription was found.")
            case .success(.unverified): throw PurchaseError.unverified
            case .pending: message = L("Your purchase is awaiting approval. Plus will unlock when Apple confirms it.")
            case .userCancelled: break
            @unknown default: message = L("The purchase has not completed. Please try again.")
            }
        } catch is CancellationError { }
        catch StoreKitError.userCancelled { }
        catch { errorMessage = error.localizedDescription }
    }
    func restore() async {
        guard !purchasing else { return }
        purchasing = true; message = nil; errorMessage = nil
        defer { purchasing = false }
        do {
            try await AppStore.sync(); await refreshEntitlements()
            message = hasPlus ? L("Your LeaveWell Plus subscription has been restored.") : L("No active LeaveWell Plus subscription was found.")
        } catch is CancellationError { }
        catch { errorMessage = L("Unable to restore purchases. Check your connection and try again.") }
    }
    func refreshEntitlements() async {
        var dates: [String: Date] = [:]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, PlusPlan.productIDs.contains(transaction.productID),
                  transaction.productType == .autoRenewable, transaction.revocationDate == nil, !transaction.isUpgraded,
                  let expiration = transaction.expirationDate, expiration > Date() else { continue }
            dates[transaction.productID] = expiration
        }
        expirationDates = dates; ownedProductIDs = Set(dates.keys)
    }
    func requirePlus() async throws {
        await refreshEntitlements()
        guard hasPlus else { throw PurchaseError.subscriptionRequired }
    }
}
enum PurchaseError: LocalizedError {
    case unverified, subscriptionRequired
    var errorDescription: String? {
        switch self {
        case .unverified: L("The purchase could not be verified. Please try restoring purchases.")
        case .subscriptionRequired: L("An active LeaveWell Plus subscription is required to create PDF evidence reports.")
        }
    }
}
