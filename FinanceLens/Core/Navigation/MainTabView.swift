import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab: Int {
        case dashboard, transactions, analytics, chat, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.dashboard)

            TransactionListView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
                .tag(Tab.transactions)

            AnalyticsDashboardView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                .tag(Tab.analytics)

//            ChatView()
//                .tabItem { Label("AI Chat", systemImage: "bubble.left.and.text.bubble.right") }
//                .tag(Tab.chat)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
    }
}
