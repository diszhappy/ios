import SwiftUI
import SwiftData

@main
struct FinanceLensApp: App {
    @StateObject private var appState = AppState()
    private let container: ModelContainer

    init() {
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
                Lending.self
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
        }
    }
}

