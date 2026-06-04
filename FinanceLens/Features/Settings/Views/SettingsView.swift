import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("biometricEnabled") private var biometricEnabled = true
    @State private var showSetPin = false
    @State private var newPin = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Security") {
                    Toggle("App Lock", isOn: $appLockEnabled)
                    if appLockEnabled {
                        Toggle("Biometric Unlock", isOn: $biometricEnabled)
                        Button("Set/Change PIN") { showSetPin = true }
                    }
                }

                Section("Data") {
                    NavigationLink("Import Statement") { ImportStatementView() }
                    NavigationLink("SMS Transactions") { SMSMonitorView() }
                    NavigationLink("Lendings & Loans") { LendingListView() }
                    NavigationLink("Budgets") { BudgetView() }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("100% Offline").foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Set PIN", isPresented: $showSetPin) {
                SecureField("4-digit PIN", text: $newPin)
                    .keyboardType(.numberPad)
                Button("Save") {
                    if newPin.count >= 4 { _ = PINManager.setPin(newPin) }
                    newPin = ""
                }
                Button("Cancel", role: .cancel) { newPin = "" }
            }
        }
    }
}
