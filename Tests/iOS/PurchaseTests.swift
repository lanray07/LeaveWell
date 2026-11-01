import XCTest
import StoreKit
import StoreKitTest
import SwiftUI
import UIKit
@testable import LeaveWell

@MainActor
final class PurchaseTests: XCTestCase {
    // StoreKitTest changes its server immediately, but StoreKit delivers client
    // entitlement updates asynchronously. Bound the wait and keep real access checks.
    private func awaitAccess(_ expected: Bool, in purchases: PurchaseService) async throws {
        let deadline = Date().addingTimeInterval(20)
        repeat {
            await purchases.refreshEntitlements()
            if purchases.hasPlus == expected { return }
            try await Task.sleep(for: .milliseconds(200))
        } while Date() < deadline
        XCTFail("StoreKit did not publish the expected Plus access state: \(expected)")
        throw TestSetupError.entitlementStateNotReady
    }
    private enum TestSetupError: Error { case entitlementStateNotReady }
    private func session() async throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LeaveWell", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions()
        session.disableDialogs = true; session.storefront = "GBR"; session.locale = Locale(identifier: "en_GB")
        // Each test owns an empty StoreKit environment. clearTransactions resets
        // the test server; explicit sync also invalidates the client transaction
        // cache before a restore regression seeds its own purchase.
        try await AppStore.sync()
        let baseline = PurchaseService()
        try await awaitAccess(false, in: baseline)
        return session
    }
    func testNoPurchaseBlocksReportAccess() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        let purchases = PurchaseService(); await purchases.load()
        XCTAssertEqual(Set(purchases.products.map(\.id)), PlusPlan.productIDs)
        XCTAssertFalse(purchases.hasPlus)
        do { try await purchases.requirePlus(); XCTFail("Free users must not create premium reports") }
        catch { XCTAssertTrue(error is PurchaseError) }
        // Save an actual, unsubscribed purchase screen for App Review; prices come from StoreKit.
        let view = NavigationStack { PlusView() }.environment(purchases)
        let host = UIHostingController(rootView: view)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 430, height: 932)
        window.rootViewController = host; window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(2))
        // The view's task reloads prices; capture after that request has completed.
        let loadingDeadline = Date().addingTimeInterval(20)
        while purchases.loading && Date() < loadingDeadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertFalse(purchases.loading)
        XCTAssertNil(purchases.errorMessage)
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TestReports")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent("LeaveWell-Plus-purchase-review.png"))
        window.isHidden = true
    }
    func testMonthlyPurchaseRestoreAndExpiry() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        let purchases = PurchaseService(); await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertTrue(purchases.hasPlus); XCTAssertNil(purchases.errorMessage)
        try await purchases.requirePlus()
        let restored = PurchaseService(); await restored.restore()
        XCTAssertTrue(restored.hasPlus)
        try session.expireSubscription(productIdentifier: PlusPlan.monthly)
        try await awaitAccess(false, in: purchases)
        XCTAssertFalse(purchases.hasPlus)
        do { try await purchases.requirePlus(); XCTFail("Expired subscriptions must lose report creation") }
        catch { XCTAssertTrue(error is PurchaseError) }
    }
    func testRestoreRecognisesVerifiedAccessBeforeRequestingAccountSync() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: PlusPlan.monthly, options: [])
        var syncCalls = 0
        let purchases = PurchaseService(syncPurchases: {
            syncCalls += 1
            throw StoreKitError.unknown
        })
        // The preflight contract is about an entitlement already visible on
        // the client, not merely a purchase seeded on the test server.
        try await awaitAccess(true, in: purchases)
        await purchases.restore()
        XCTAssertTrue(purchases.hasPlus, "Restore must read StoreKit's verified entitlement even when account sync would fail")
        XCTAssertEqual(syncCalls, 0, "An already active verified subscription needs no account authentication")
        XCTAssertNil(purchases.errorMessage)
        XCTAssertNotNil(purchases.message)
        XCTAssertFalse(purchases.purchasing)
    }
    func testRestoreRefreshesVerifiedAccessAfterSyncFails() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        var syncCalls = 0
        let purchases = PurchaseService(syncPurchases: {
            syncCalls += 1
            // A transaction can become available while Apple is authenticating.
            _ = try await session.buyProduct(identifier: PlusPlan.monthly, options: [])
            throw StoreKitError.unknown
        })
        try await awaitAccess(false, in: purchases)
        await purchases.restore()
        XCTAssertTrue(purchases.hasPlus)
        XCTAssertEqual(syncCalls, 1, "This regression must reach the failing sync callback")
        XCTAssertNotNil(purchases.errorMessage, "A failed sync must still be disclosed even when verified access is available")
        XCTAssertNotNil(purchases.message)
        XCTAssertFalse(purchases.purchasing)
    }
    func testCancelledRestoreDoesNotShowFailureOrUnlockAccess() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        let purchases = PurchaseService(syncPurchases: { throw StoreKitError.userCancelled })
        try await awaitAccess(false, in: purchases)
        await purchases.restore()
        XCTAssertFalse(purchases.hasPlus)
        XCTAssertNil(purchases.errorMessage)
        XCTAssertNil(purchases.message)
        XCTAssertFalse(purchases.purchasing)
    }
    func testFailedRestoreWithoutEntitlementNeverUnlocksAccess() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        let purchases = PurchaseService(syncPurchases: { throw StoreKitError.unknown })
        try await awaitAccess(false, in: purchases)
        await purchases.restore()
        XCTAssertFalse(purchases.hasPlus)
        XCTAssertTrue(purchases.ownedProductIDs.isEmpty)
        XCTAssertNotNil(purchases.errorMessage)
        XCTAssertNil(purchases.message)
        XCTAssertFalse(purchases.purchasing)
    }
    func testRestoreSyncsWhenNoActiveEntitlementExists() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        var syncCalls = 0
        let purchases = PurchaseService(syncPurchases: { syncCalls += 1 })
        try await awaitAccess(false, in: purchases)
        await purchases.restore()
        XCTAssertEqual(syncCalls, 1)
        XCTAssertFalse(purchases.hasPlus)
        XCTAssertNil(purchases.errorMessage)
        XCTAssertEqual(purchases.message, L("No active LeaveWell Plus subscription was found."))
    }
    func testRestoreDiscoversVerifiedPurchaseAfterSuccessfulSync() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        var syncCalls = 0
        let purchases = PurchaseService(syncPurchases: {
            syncCalls += 1
            try await AppStore.sync()
            _ = try await session.buyProduct(identifier: PlusPlan.annual, options: [])
        })
        try await awaitAccess(false, in: purchases)
        await purchases.restore()
        XCTAssertEqual(syncCalls, 1)
        XCTAssertTrue(purchases.hasPlus)
        XCTAssertNil(purchases.errorMessage)
        XCTAssertEqual(purchases.message, L("Your LeaveWell Plus subscription has been restored."))
        try await purchases.requirePlus()
    }
    func testRepeatedRestoreTapDoesNotStartSecondSync() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        var releaseSync: CheckedContinuation<Void, Never>?
        var syncCalls = 0
        let purchases = PurchaseService(syncPurchases: {
            syncCalls += 1
            await withCheckedContinuation { releaseSync = $0 }
        })
        try await awaitAccess(false, in: purchases)
        let first = Task { await purchases.restore() }
        let deadline = Date().addingTimeInterval(20)
        while releaseSync == nil && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        guard let releaseSync else {
            first.cancel()
            XCTFail("Restore did not reach account sync")
            return
        }
        await purchases.restore()
        XCTAssertEqual(syncCalls, 1)
        XCTAssertTrue(purchases.purchasing)
        releaseSync.resume()
        await first.value
        XCTAssertFalse(purchases.purchasing)
    }
    func testAnnualRefundRemovesAccessAndRenewalPreservesAccess() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: PlusPlan.annual, options: [])
        let purchases = PurchaseService(); await purchases.refreshEntitlements()
        XCTAssertTrue(purchases.hasPlus)
        try session.forceRenewalOfSubscription(productIdentifier: PlusPlan.annual)
        await purchases.refreshEntitlements(); XCTAssertTrue(purchases.hasPlus)
        let transaction = try XCTUnwrap(session.allTransactions().max { $0.identifier < $1.identifier })
        try session.refundTransaction(identifier: transaction.identifier)
        try await awaitAccess(false, in: purchases); XCTAssertFalse(purchases.hasPlus)
        do { try await purchases.requirePlus(); XCTFail("Refunded subscriptions must lose report creation") }
        catch { XCTAssertTrue(error is PurchaseError) }
    }
    func testCancelledPurchaseDoesNotUnlockPlus() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let purchases = PurchaseService(); await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertFalse(purchases.hasPlus); XCTAssertFalse(purchases.purchasing)
    }
    func testUnverifiedPurchaseDoesNotUnlockPlus() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        let purchases = PurchaseService()
        // Clearing the test server does not synchronously invalidate StoreKit's
        // client cache. Establish the locked starting state before injecting an
        // invalid signature, so an earlier approval cannot masquerade as access.
        try await awaitAccess(false, in: purchases)
        XCTAssertFalse(purchases.hasPlus)
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        let simulated = await session.simulatedError(forAPI: .verification)
        XCTAssertNotNil(simulated, "The test must inject an invalid signature")
        await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertFalse(purchases.hasPlus); XCTAssertNotNil(purchases.errorMessage)
    }
    func testPendingPurchaseUnlocksOnlyAfterApproval() async throws {
        let session = try await session(); defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let purchases = PurchaseService(); await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertFalse(purchases.hasPlus); XCTAssertNotNil(purchases.message)
        let transaction = try XCTUnwrap(session.allTransactions().last)
        XCTAssertTrue(transaction.pendingAskToBuyConfirmation)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        // Approval returns before StoreKit delivers the verified entitlement.
        // Wait for the same real access signal used by expiry/refund tests.
        try await awaitAccess(true, in: purchases)
        XCTAssertTrue(purchases.hasPlus)
    }
}
