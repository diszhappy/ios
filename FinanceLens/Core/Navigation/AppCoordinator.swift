import SwiftUI

struct AppCoordinator: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var context
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    var body: some View {
        Group {
            if appLockEnabled && !appState.isUnlocked {
                LockScreenView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isUnlocked)
        .task {
            RecurringTransactionService(context: context).processRecurringTransactions()
        }
    }
}
