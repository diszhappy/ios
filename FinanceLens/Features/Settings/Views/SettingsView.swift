import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var context

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("biometricEnabled") private var biometricEnabled = true
    @AppStorage("dailyNotifications") private var dailyNotifications = false
    @AppStorage("weeklyNotifications") private var weeklyNotifications = false
    @AppStorage("secureMode") private var secureMode = false
    @AppStorage("dailyNotifHour") private var dailyNotifHour = 21
    @AppStorage("dailyNotifMinute") private var dailyNotifMinute = 0
    @AppStorage("weeklyNotifHour") private var weeklyNotifHour = 10
    @AppStorage("weeklyNotifMinute") private var weeklyNotifMinute = 0

    @State private var showSetPin = false
    @State private var newPin = ""
    @State private var dailyTime = Date()
    @State private var weeklyTime = Date()

    var body: some View {
        NavigationStack {
            List {
                Section("Security") {
                    Toggle("App Lock", isOn: $appLockEnabled)
                    if appLockEnabled {
                        Toggle("Biometric Unlock", isOn: $biometricEnabled)
                        Button("Set/Change PIN") { showSetPin = true }
                    }
                    Toggle("Secure Mode", isOn: $secureMode)
                    if secureMode {
                        Text("All amounts hidden as ****")
                            .font(.caption).foregroundStyle(.secondary)
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
                    NavigationLink("Reports") { ReportsView() }
                }

                Section("Notifications") {
                    Toggle("Daily Summary", isOn: $dailyNotifications)
                        .onChange(of: dailyNotifications) { _, enabled in
                            scheduleDaily(enabled: enabled)
                        }
                    if dailyNotifications {
                        DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                            .onChange(of: dailyTime) { _, newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                dailyNotifHour = comps.hour ?? 21
                                dailyNotifMinute = comps.minute ?? 0
                                scheduleDaily(enabled: true)
                            }
                    }

                    Toggle("Weekly Report (Sunday)", isOn: $weeklyNotifications)
                        .onChange(of: weeklyNotifications) { _, enabled in
                            scheduleWeekly(enabled: enabled)
                        }
                    if weeklyNotifications {
                        DatePicker("Time", selection: $weeklyTime, displayedComponents: .hourAndMinute)
                            .onChange(of: weeklyTime) { _, newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                weeklyNotifHour = comps.hour ?? 10
                                weeklyNotifMinute = comps.minute ?? 0
                                scheduleWeekly(enabled: true)
                            }
                    }
                }

                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }
                    HStack { Text("Privacy"); Spacer(); Text("100% Offline").foregroundStyle(.green) }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                dailyTime = makeTime(hour: dailyNotifHour, minute: dailyNotifMinute)
                weeklyTime = makeTime(hour: weeklyNotifHour, minute: weeklyNotifMinute)
            }
            .alert("Set PIN", isPresented: $showSetPin) {
                SecureField("4-digit PIN", text: $newPin).keyboardType(.numberPad)
                Button("Save") { if newPin.count >= 4 { PINManager.setPin(newPin) }; newPin = "" }
                Button("Cancel", role: .cancel) { newPin = "" }
            }
        }
    }

    private func scheduleDaily(enabled: Bool) {
        let service = SpendingNotificationService(context: context)
        if enabled {
            Task { await service.scheduleDailyNotification(hour: dailyNotifHour, minute: dailyNotifMinute) }
        } else {
            service.cancelAll()
        }
    }

    private func scheduleWeekly(enabled: Bool) {
        let service = SpendingNotificationService(context: context)
        if enabled {
            Task { await service.scheduleWeeklyNotification(weekday: 1, hour: weeklyNotifHour, minute: weeklyNotifMinute) }
        } else {
            service.cancelAll()
        }
    }

    private func makeTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}
