import XCTest
import UIKit
@testable import LeaveWell

@MainActor
final class PrivacyTests: XCTestCase {
    func testPrivacyShieldCoversPresentedWindowsUntilAuthenticated() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let authentication = Authentication()
        let lock = AppLock(makeAuthentication: { authentication })
        defer { lock.updateShield(enabled: false, active: true) }
        let underlying = scene.windows.map { ($0, $0.accessibilityElementsHidden) }
        lock.updateShield(enabled: true, active: true)
        let shield = try XCTUnwrap(scene.windows.first { $0.windowLevel > .alert && !$0.isHidden })
        XCTAssertNotNil(shield.rootViewController)
        XCTAssertEqual(shield.rootViewController?.view.accessibilityViewIsModal, true)
        XCTAssertTrue(underlying.allSatisfy { $0.0.accessibilityElementsHidden }, "Locked content must also be hidden from accessibility")
        XCTAssertFalse(shield.isKeyWindow, "Shield must not steal the app's input window")
        let request = Task { await lock.unlock() }
        while authentication.continuation == nil { await Task.yield() }
        authentication.continuation?.resume(returning: true)
        await request.value
        lock.updateShield(enabled: true, active: false)
        XCTAssertFalse(shield.isHidden, "Inactive scenes stay shielded even after successful authentication")
        lock.updateShield(enabled: true, active: true)
        XCTAssertTrue(shield.isHidden)
        XCTAssertTrue(underlying.allSatisfy { $0.0.accessibilityElementsHidden == $0.1 })
    }
    private final class Authentication: DeviceAuthenticating {
        var continuation: CheckedContinuation<Bool, Error>?
        var invalidated = false
        var calls = 0
        func evaluate() async throws -> Bool {
            calls += 1
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        func invalidate() { invalidated = true }
    }
    func testBackgroundInvalidatesAuthenticationAndRejectsLateSuccess() async {
        let authentication = Authentication()
        let lock = AppLock(makeAuthentication: { authentication })
        let request = Task { await lock.unlock() }
        while authentication.continuation == nil { await Task.yield() }
        lock.lock()
        XCTAssertTrue(authentication.invalidated)
        authentication.continuation?.resume(returning: true)
        await request.value
        XCTAssertFalse(lock.unlocked)
        XCTAssertFalse(lock.authenticating)
    }
    func testRepeatedUnlockUsesOneRequestAndFreshUnlockWorks() async {
        let authentication = Authentication()
        let lock = AppLock(makeAuthentication: { authentication })
        let request = Task { await lock.unlock() }
        while authentication.continuation == nil { await Task.yield() }
        await lock.unlock()
        XCTAssertEqual(authentication.calls, 1)
        authentication.continuation?.resume(returning: true)
        await request.value
        XCTAssertTrue(lock.unlocked)
        lock.lock()
        XCTAssertFalse(lock.unlocked)
    }
    func testMicrophonePermissionCannotStartRecordingAfterCancellation() async {
        var permission: CheckedContinuation<Bool, Never>?
        let voice = VoiceService(requestPermission: {
            await withCheckedContinuation { permission = $0 }
        })
        let request = Task { await voice.start() }
        while permission == nil { await Task.yield() }
        XCTAssertTrue(voice.starting)
        voice.cancel()
        permission?.resume(returning: true)
        await request.value
        XCTAssertFalse(voice.recording)
        XCTAssertFalse(voice.starting)
        XCTAssertNil(voice.recordingURL)
        XCTAssertNil(voice.startedAt)
    }
}
