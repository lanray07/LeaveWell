import LocalAuthentication
import Observation

@MainActor @Observable
final class AppLock {
    var unlocked = false
    var message: String?
    func unlock() async {
        let context = LAContext()
        do {
            unlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L("Unlock your private move-out records."))
            message = nil
        } catch { message = L("Your records are locked. Try again when you are ready.") }
    }
}
