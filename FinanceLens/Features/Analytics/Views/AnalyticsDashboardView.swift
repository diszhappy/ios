import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var categoryData: [CategoryAnalytics] = []
    @State private var cashFlow: CashFlowAnalytics?
    @State private var topMerchants: [MerchantAnalytics] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let cf = cashFlow {
                        cashFlowCard(cf)
                    }
                    categoryChart
                    merchantChart
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .onAppear { loadData() }
        }
    }

    private func cashFlowCard(_ cf: CashFlowAnalytics) -> some View {
        VStack(spacing: 12) {
            HStack {
                statBox(title: "Income", value: cf.income, color: .green)
                statBox(title: "Expense", value: cf.expense, color: .red)
                statBox(title: "Savings", value: cf.netFlow, color: .blue)
            }
            Text("Savings Rate: \(cf.savingsRate, specifier: "%.1f")%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statBox(title: String, value: Double, color: Color) -> some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("₹\(value, specifier: "%.0f")").font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    @State private var selectedCategoryItem: String?
    @State private var selectedMerchantItem: String?

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending by Category").font(.headline)

            if let selected = selectedCategoryItem,
               let item = categoryData.first(where: { $0.category == selected }) {
                HStack {
                    Text(item.category).font(.subheadline.bold())
                    Spacer()
                    Text("₹\(item.amount, specifier: "%.0f") (\(item.percentage, specifier: "%.1f")%)")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !categoryData.isEmpty {
                Chart(categoryData.prefix(8), id: \.category) { item in
                    BarMark(
                        x: .value("Amount", item.amount),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .opacity(selectedCategoryItem == nil || selectedCategoryItem == item.category ? 1 : 0.4)
                }
                .chartYSelection(value: $selectedCategoryItem)
                .frame(height: 280)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var merchantChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Merchants").font(.headline)

            if let selected = selectedMerchantItem,
               let item = topMerchants.first(where: { $0.merchant == selected }) {
                HStack {
                    Text(item.merchant).font(.subheadline.bold())
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("₹\(item.totalSpent, specifier: "%.0f")")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text("\(item.transactionCount) txns · avg ₹\(item.averageAmount, specifier: "%.0f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !topMerchants.isEmpty {
                Chart(topMerchants.prefix(8), id: \.merchant) { item in
                    BarMark(
                        x: .value("Amount", item.totalSpent),
                        y: .value("Merchant", item.merchant)
                    )
                    .foregroundStyle(.orange.gradient)
                    .opacity(selectedMerchantItem == nil || selectedMerchantItem == item.merchant ? 1 : 0.4)
                }
                .chartYSelection(value: $selectedMerchantItem)
                .frame(height: 280)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadData() {
        let repo = TransactionRepository(context: context)
        let engine = AnalyticsEngine(repository: repo)
        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        do {
            categoryData = try engine.categoryAnalytics(from: startOfMonth, to: now)
            cashFlow = try engine.cashFlowAnalytics(from: startOfMonth, to: now)
            topMerchants = try engine.merchantAnalytics(from: startOfMonth, to: now)
        } catch {
            print("Analytics error: \(error)")
        }
    }
}
