import Foundation
import LocalAuthentication

/// App lock via LocalAuthentication. No account — biometric/device passcode only.
@MainActor
@Observable
final class AppLockService {
    private(set) var isUnlocked = false
    private(set) var biometricsAvailable = false
    private(set) var biometryLabel = "Face ID"

    init() {
        refreshBiometryAvailability()
    }

    func refreshBiometryAvailability() {
        let context = LAContext()
        var error: NSError?
        biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)

        switch context.biometryType {
        case .faceID: biometryLabel = "Face ID"
        case .touchID: biometryLabel = "Touch ID"
        case .opticID: biometryLabel = "Optic ID"
        default: biometryLabel = "Device passcode"
        }
    }

    func lock() {
        isUnlocked = false
    }

    func markUnlocked() {
        isUnlocked = true
    }

    func unlock(reason: String = "Unlock Lune to view your health data") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            isUnlocked = success
            return success
        } catch {
            isUnlocked = false
            return false
        }
    }
}
