import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var context
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("biometricEnabled") private var biometricEnabled = true
    @AppStorage("dailyNotifications") private var dailyNotifications = false
    @AppStorage("weeklyNotifications") private var weeklyNotifications = false
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
                    NavigationLink("Split Expenses") { SplitExpenseListView() }
                    NavigationLink("Savings Goals") { GoalsView() }
                    NavigationLink("Budgets") { BudgetView() }
                    NavigationLink("Backup & Restore") { BackupRestoreView() }
                }

                Section("Notifications") {
                    Toggle("Daily Summary (9 PM)", isOn: $dailyNotifications)
                        .onChange(of: dailyNotifications) { _, enabled in
                            let service = SpendingNotificationService(context: context)
                            if enabled { service.requestPermission(); service.scheduleDailyNotification() }
                            else { service.cancelAll() }
                        }
                    Toggle("Weekly Report (Sunday)", isOn: $weeklyNotifications)
                        .onChange(of: weeklyNotifications) { _, enabled in
                            let service = SpendingNotificationService(context: context)
                            if enabled { service.requestPermission(); service.scheduleWeeklyNotification() }
                            else { service.cancelAll() }
                        }
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
                    if newPin.count >= 4 { PINManager.setPin(newPin) }
                    newPin = ""
                }
                Button("Cancel", role: .cancel) { newPin = "" }
            }
        }
    }
}
