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
    }
    private func session() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LeaveWell", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions()
        session.disableDialogs = true; session.storefront = "GBR"; session.locale = Locale(identifier: "en_GB")
        return session
    }
    func testNoPurchaseBlocksReportAccess() async throws {
        let session = try session(); defer { session.clearTransactions() }
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
        let session = try session(); defer { session.clearTransactions() }
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
    func testAnnualRefundRemovesAccessAndRenewalPreservesAccess() async throws {
        let session = try session(); defer { session.clearTransactions() }
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
        let session = try session(); defer { session.clearTransactions() }
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let purchases = PurchaseService(); await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertFalse(purchases.hasPlus); XCTAssertFalse(purchases.purchasing)
    }
    func testUnverifiedPurchaseDoesNotUnlockPlus() async throws {
        let session = try session(); defer { session.clearTransactions() }
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        let purchases = PurchaseService(); await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertFalse(purchases.hasPlus); XCTAssertNotNil(purchases.errorMessage)
    }
    func testPendingPurchaseUnlocksOnlyAfterApproval() async throws {
        let session = try session(); defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let purchases = PurchaseService(); await purchases.load()
        let monthly = try XCTUnwrap(purchases.products.first { $0.id == PlusPlan.monthly })
        await purchases.purchase(monthly)
        XCTAssertFalse(purchases.hasPlus); XCTAssertNotNil(purchases.message)
        let transaction = try XCTUnwrap(session.allTransactions().last)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await purchases.refreshEntitlements(); XCTAssertTrue(purchases.hasPlus)
    }
}
