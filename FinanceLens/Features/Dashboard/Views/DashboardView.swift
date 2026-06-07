import SwiftUI
import Charts
import WidgetKit

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var totalExpense: Double = 0
    @State private var totalIncome: Double = 0
    @State private var healthScore: Int = 0
    @State private var topCategories: [(String, Double)] = []
    @State private var recentTransactions: [Transaction] = []
    @State private var budgetUsage: Double = 0
    @State private var showImport = false
    @State private var showAddTransaction = false
    @StateObject private var transactionVM = TransactionViewModel()

    @State private var selectedCategory: String?
    @State private var drilldownData: [(String, Double)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCards
                    healthScoreCard
                    categoryChart
                    if selectedCategory != nil {
                        drilldownChart
                    }
                    recentTransactionsSection
                }
                .padding()
            }
            .navigationTitle("FinanceLens")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showImport = true } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showImport) { ImportStatementView() }
            .sheet(isPresented: $showAddTransaction) { AddTransactionView(viewModel: transactionVM) }
            .onAppear { transactionVM.setup(context: context) }
            .task { await loadDashboard() }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCard(title: "Income", value: totalIncome, color: .green, icon: "arrow.down.circle.fill")
            SummaryCard(title: "Expense", value: totalExpense, color: .red, icon: "arrow.up.circle.fill")
            SummaryCard(title: "Savings", value: totalIncome - totalExpense, color: .blue, icon: "banknote.fill")
        }
    }

    private var healthScoreCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Financial Health")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(healthScore)/100")
                    .font(.title.bold())
                    .foregroundStyle(scoreColor)
            }
            Spacer()
            CircularProgressView(progress: Double(healthScore) / 100, color: scoreColor)
                .frame(width: 50, height: 50)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending by Category").font(.headline)
                Spacer()
                if selectedCategory != nil {
                    Button("Back") {
                        withAnimation { selectedCategory = nil; drilldownData = [] }
                    }
                    .font(.subheadline)
                }
            }
            if !topCategories.isEmpty {
                Chart(topCategories.prefix(8), id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", item.1),
                        innerRadius: .ratio(0.6),
                        outerRadius: selectedCategory == item.0 ? .ratio(1.0) : .ratio(0.9)
                    )
                    .foregroundStyle(by: .value("Category", item.0))
                    .opacity(selectedCategory == nil || selectedCategory == item.0 ? 1 : 0.4)
                }
                .frame(height: 200)

                // Tappable category list for drilldown
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(topCategories.prefix(8), id: \.0) { name, amount in
                        Button {
                            withAnimation {
                                selectedCategory = name
                                loadDrilldown(category: name)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(name)
                                    .font(.caption2.bold())
                                    .lineLimit(1)
                                Text("₹\(amount, specifier: "%.0f")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedCategory == name ? Color.blue.opacity(0.2) : Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var drilldownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(selectedCategory ?? "") Breakdown")
                .font(.headline)
            if !drilldownData.isEmpty {
                Chart(drilldownData, id: \.0) { item in
                    BarMark(
                        x: .value("Amount", item.1),
                        y: .value("Merchant", item.0)
                    )
                    .foregroundStyle(.blue.gradient)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("₹\(item.1, specifier: "%.0f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(drilldownData.count * 40 + 20))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func loadDrilldown(category: String) {
        let repo = TransactionRepository(context: context)
        let period = DateRange.thisMonth
        do {
            let transactions = try repo.fetchAll(from: period.start, to: period.end, category: category)
                .filter { $0.transactionType != .credit }
            var merchantTotals: [String: Double] = [:]
            for t in transactions {
                merchantTotals[t.merchant, default: 0] += t.amount
            }
            drilldownData = merchantTotals.sorted { $0.value > $1.value }
                .prefix(8).map { ($0.key, $0.value) }
        } catch {
            drilldownData = []
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading) {
            Text("Recent Transactions").font(.headline)
            ForEach(recentTransactions.prefix(5), id: \.id) { t in
                HStack {
                    Text(t.merchant).font(.subheadline)
                    Spacer()
                    Text("₹\(t.amount, specifier: "%.0f")")
                        .foregroundStyle(t.transactionType == .credit ? .green : .primary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scoreColor: Color {
        switch healthScore {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .red
        }
    }

    private func loadDashboard() async {
        let repo = TransactionRepository(context: context)
        let budgetRepo = BudgetRepository(context: context)
        let period = DateRange.thisMonth

        do {
            totalExpense = try repo.totalSpending(from: period.start, to: period.end)
            totalIncome = try repo.totalIncome(from: period.start, to: period.end)
            let byCategory = try repo.spendingByCategory(from: period.start, to: period.end)
            topCategories = byCategory.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
            recentTransactions = Array(try repo.fetchAll(from: period.start, to: period.end).prefix(5))

            // Today's spending for widget
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())
            let todaySpent = try repo.totalSpending(from: todayStart, to: .now)

            // Budget remaining
            let budgets = try budgetRepo.fetchBudgets(month: cal.component(.month, from: .now), year: cal.component(.year, from: .now))
            let budgetRemaining = budgets.reduce(0.0) { $0 + $1.remaining }

            // Share with widget via App Group  
            let shared = UserDefaults(suiteName: "group.com.financelens.ai")
            shared?.set(todaySpent, forKey: "todaySpent")
            shared?.set(totalExpense, forKey: "monthSpent")
            shared?.set(budgetRemaining, forKey: "budgetRemaining")
            shared?.set(topCategories.first?.0 ?? "-", forKey: "topCategory")
            WidgetCenter.shared.reloadAllTimelines()

            // Defer heavy health score calculation
            Task.detached { @MainActor [repo, budgetRepo] in
                let healthEngine = FinancialHealthEngine(repository: repo, budgetRepository: budgetRepo)
                self.healthScore = (try? healthEngine.calculateScore().score) ?? 0
            }
        } catch {
            print("Dashboard error: \(error)")
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("₹\(value, specifier: "%.0f")")
                .font(.subheadline.bold())
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
