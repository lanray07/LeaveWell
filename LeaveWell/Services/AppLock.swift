import LocalAuthentication
import Observation

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
    private var generation = 0
    init(makeAuthentication: @escaping () -> any DeviceAuthenticating) {
        self.makeAuthentication = makeAuthentication
    }
    convenience init() { self.init(makeAuthentication: { DeviceAuthentication() }) }
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
