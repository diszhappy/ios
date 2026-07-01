import SwiftUI
import SwiftData
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct FinanceLensApp: App {
    @StateObject private var appState = AppState()
    private let container: ModelContainer
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate

        do {
            let schema = Schema([
                Transaction.self,
                Category.self,
                Budget.self,
                Subscription.self,
                Merchant.self,
                ChatSession.self,
                ChatMessage.self,
                Forecast.self,
                AppSettings.self,
                Lending.self,
                SavingsGoal.self,
                SplitExpense.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environmentObject(appState)
                .modelContainer(container)
                .scrollDismissesKeyboard(.interactively)
        }
    }
}
