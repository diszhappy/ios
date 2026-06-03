import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var biometricAuth = BiometricAuthManager()
    @State private var pin = ""
    @State private var showPinEntry = false
    @State private var errorMessage: String?
    @AppStorage("biometricEnabled") private var biometricEnabled = true

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("FinanceLens AI")
                .font(.title.bold())

            Text("Unlock to access your finances")
                .foregroundStyle(.secondary)

            if showPinEntry {
                pinEntryView
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()

            if biometricEnabled && biometricAuth.isAvailable {
                Button {
                    Task { await authenticateWithBiometric() }
                } label: {
                    Label(
                        biometricAuth.biometricType == .faceID ? "Unlock with Face ID" : "Unlock with Touch ID",
                        systemImage: biometricAuth.biometricType == .faceID ? "faceid" : "touchid"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }

            if PINManager.hasPin() {
                Button("Use PIN") {
                    showPinEntry = true
                }
                .padding(.bottom)
            }
        }
        .padding()
        .onAppear {
            biometricAuth.checkAvailability()
        }
        .task {
            if biometricEnabled && biometricAuth.isAvailable {
                await authenticateWithBiometric()
            } else {
                showPinEntry = PINManager.hasPin()
            }
        }
    }

    @State private var showResetConfirmation = false
    @State private var showNewPinEntry = false
    @State private var showCaptcha = false
    @State private var newPin = ""
    @State private var captchaAnswer = ""
    @State private var captchaA = 0
    @State private var captchaB = 0

    private var pinEntryView: some View {
        VStack(spacing: 16) {
            SecureField("Enter PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.password)
                .frame(width: 200)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button("Unlock") {
                if PINManager.verifyPin(pin) {
                    appState.unlock()
                } else {
                    errorMessage = "Incorrect PIN"
                    pin = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(pin.count < 4)

            Button("Forgot PIN?") {
                Task { await attemptBiometricReset() }
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .alert("Verify You're Human", isPresented: $showCaptcha) {
            TextField("Answer", text: $captchaAnswer)
                .keyboardType(.numberPad)
            Button("Verify") {
                if captchaAnswer == "\(captchaA + captchaB)" {
                    captchaAnswer = ""
                    showNewPinEntry = true
                } else {
                    captchaAnswer = ""
                    errorMessage = "Wrong answer. Try again."
                }
            }
            Button("Cancel", role: .cancel) { captchaAnswer = "" }
        } message: {
            Text("Solve: \(captchaA) + \(captchaB) = ?")
        }
        .alert("Set New PIN", isPresented: $showNewPinEntry) {
            SecureField("New 4-digit PIN", text: $newPin)
                .keyboardType(.numberPad)
            Button("Save") {
                if newPin.count >= 4 {
                    PINManager.setPin(newPin)
                    newPin = ""
                    errorMessage = nil
                    pin = ""
                }
            }
            Button("Cancel", role: .cancel) { newPin = "" }
        } message: {
            Text("Enter a new 4-digit PIN.")
        }
    }

    private func attemptBiometricReset() async {
        if await biometricAuth.authenticate() {
            showNewPinEntry = true
        } else {
            generateCaptcha()
            showCaptcha = true
        }
    }

    private func generateCaptcha() {
        captchaA = Int.random(in: 10...50)
        captchaB = Int.random(in: 10...50)
    }

    private func authenticateWithBiometric() async {
        if await biometricAuth.authenticate() {
            appState.unlock()
        }
    }
}
