import LocalAuthentication
import Foundation

@MainActor
final class BiometricAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var biometricType: LABiometryType = .none
    @Published var isAvailable = false
    @Published var error: String?

    /// Call once on appear — not during body evaluation
    func checkAvailability() {
        let context = LAContext()
        var nsError: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError)
        isAvailable = available
        if available {
            biometricType = context.biometryType
        }
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use PIN"

        var nsError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError) else {
            error = nsError?.localizedDescription
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock FinanceLens"
            )
            isAuthenticated = success
            return success
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
