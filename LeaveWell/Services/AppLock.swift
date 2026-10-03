import LocalAuthentication
import Observation
import SwiftUI
import UIKit

@MainActor
protocol DeviceAuthenticating {
    func evaluate() async throws -> Bool
    func invalidate()
}

@MainActor
private final class DeviceAuthentication: DeviceAuthenticating {
    private let context = LAContext()
    func evaluate() async throws -> Bool {
        try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L("Unlock your private move-out records."))
    }
    func invalidate() { context.invalidate() }
}

@MainActor @Observable
final class AppLock {
    private(set) var unlocked = false
    private(set) var authenticating = false
    var message: String?
    @ObservationIgnored private let makeAuthentication: () -> any DeviceAuthenticating
    @ObservationIgnored private var authentication: (any DeviceAuthenticating)?
    @ObservationIgnored private var privacyWindows: [String: UIWindow] = [:]
    @ObservationIgnored private var hiddenAccessibilityWindows: [(UIWindow, Bool)] = []
    private var generation = 0
    init(makeAuthentication: @escaping () -> any DeviceAuthenticating) {
        self.makeAuthentication = makeAuthentication
    }
    convenience init() { self.init(makeAuthentication: { DeviceAuthentication() }) }
    static var authenticationAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
    func updateShield(enabled: Bool, active: Bool) {
        guard enabled && (!unlocked || !active) else {
            for window in privacyWindows.values { window.isHidden = true }
            privacyWindows.removeAll()
            for (window, wasHidden) in hiddenAccessibilityWindows { window.accessibilityElementsHidden = wasHidden }
            hiddenAccessibilityWindows.removeAll()
            return
        }
        // A separate window also covers presented camera, Quick Look and share
        // controllers, which can otherwise sit above a SwiftUI root overlay.
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let id = scene.session.persistentIdentifier
            let window = privacyWindows[id] ?? UIWindow(windowScene: scene)
            for underlying in scene.windows where underlying !== window && !privacyWindows.values.contains(where: { $0 === underlying }) {
                if !hiddenAccessibilityWindows.contains(where: { $0.0 === underlying }) {
                    hiddenAccessibilityWindows.append((underlying, underlying.accessibilityElementsHidden))
                }
                underlying.accessibilityElementsHidden = true
            }
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: AppLockScreen(lock: self, active: active))
            window.rootViewController?.view.accessibilityViewIsModal = true
            window.isHidden = false
            privacyWindows[id] = window
        }
    }
    func lock() {
        generation += 1
        authentication?.invalidate(); authentication = nil
        authenticating = false; unlocked = false
    }
    func unlock() async {
        guard !authenticating else { return }
        let request = generation
        let context = makeAuthentication()
        authentication = context; authenticating = true
        defer { if request == generation { authentication = nil; authenticating = false } }
        do {
            let result = try await context.evaluate()
            guard request == generation else { return }
            unlocked = result
            message = nil
        } catch {
            guard request == generation else { return }
            unlocked = false; message = L("Your records are locked. Try again when you are ready.")
        }
    }
}

private struct AppLockScreen: View {
    let lock: AppLock
    let active: Bool
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.shield").font(.system(size: 60)).foregroundStyle(Theme.accent)
                Text(L("Your evidence stays private")).font(.title2.bold())
                if let message = lock.message { Text(message).foregroundStyle(.secondary) }
                Button(L("Unlock LeaveWell")) { Task { await lock.unlock() } }
                    .buttonStyle(PrimaryButton()).disabled(lock.authenticating || !active)
            }.padding(32)
        }.tint(Theme.accent)
    }
}
