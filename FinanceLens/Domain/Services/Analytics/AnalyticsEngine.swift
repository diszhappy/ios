import Foundation

struct SpendingAnalytics {
    let totalExpense: Double
    let totalIncome: Double
    let savings: Double
    let dailyAverage: Double
    let transactionCount: Int
}

struct CategoryAnalytics {
    let category: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int
    let trend: Double // positive = increasing, negative = decreasing
}

struct MerchantAnalytics {
    let merchant: String
    let totalSpent: Double
    let transactionCount: Int
    let averageAmount: Double
    let lastTransaction: Date
}

struct CashFlowAnalytics {
    let income: Double
    let expense: Double
    let netFlow: Double
    let savingsRate: Double
}

struct PeriodComparison {
    let currentPeriod: Double
    let previousPeriod: Double
    let changePercent: Double
    let direction: TrendDirection
}

enum TrendDirection { case up, down, flat }

@MainActor
final class AnalyticsEngine {
    private let repository: TransactionRepository

    init(repository: TransactionRepository) {
        self.repository = repository
    }

    // MARK: - Spending Analytics

    func spendingAnalytics(from startDate: Date, to endDate: Date) throws -> SpendingAnalytics {
        let expense = try repository.totalSpending(from: startDate, to: endDate)
        let income = try repository.totalIncome(from: startDate, to: endDate)
        let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
        let transactions = try repository.fetchAll(from: startDate, to: endDate)

        return SpendingAnalytics(
            totalExpense: expense,
            totalIncome: income,
            savings: income - expense,
            dailyAverage: expense / Double(days),
            transactionCount: transactions.count
        )
    }

    // MARK: - Category Analytics

    func categoryAnalytics(from startDate: Date, to endDate: Date) throws -> [CategoryAnalytics] {
        let spending = try repository.spendingByCategory(from: startDate, to: endDate)
        let total = spending.values.reduce(0, +)
        guard total > 0 else { return [] }

        // Previous period for trend
        let duration = endDate.timeIntervalSince(startDate)
        let prevStart = startDate.addingTimeInterval(-duration)
        let prevSpending = try repository.spendingByCategory(from: prevStart, to: startDate)

        let transactions = try repository.fetchAll(from: startDate, to: endDate)

        return spending.map { category, amount in
            let count = transactions.filter { $0.categoryName == category && $0.transactionType != .credit }.count
            let prevAmount = prevSpending[category] ?? 0
            let trend = prevAmount > 0 ? ((amount - prevAmount) / prevAmount) * 100 : 0

            return CategoryAnalytics(
                category: category,
                amount: amount,
                percentage: (amount / total) * 100,
                transactionCount: count,
                trend: trend
            )
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Merchant Analytics

    func merchantAnalytics(from startDate: Date, to endDate: Date, limit: Int = 10) throws -> [MerchantAnalytics] {
        let transactions = try repository.fetchAll(from: startDate, to: endDate)
            .filter { $0.transactionType != .credit }

        var merchantData: [String: (total: Double, count: Int, last: Date)] = [:]
        for t in transactions {
            let existing = merchantData[t.normalizedMerchant]
            merchantData[t.normalizedMerchant] = (
                total: (existing?.total ?? 0) + t.amount,
                count: (existing?.count ?? 0) + 1,
                last: max(existing?.last ?? .distantPast, t.transactionDate)
            )
        }

        return merchantData.map { merchant, data in
            MerchantAnalytics(
                merchant: merchant,
                totalSpent: data.total,
                transactionCount: data.count,
                averageAmount: data.total / Double(data.count),
                lastTransaction: data.last
            )
        }
        .sorted { $0.totalSpent > $1.totalSpent }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Cash Flow

    func cashFlowAnalytics(from startDate: Date, to endDate: Date) throws -> CashFlowAnalytics {
        let income = try repository.totalIncome(from: startDate, to: endDate)
        let expense = try repository.totalSpending(from: startDate, to: endDate)
        let savingsRate = income > 0 ? ((income - expense) / income) * 100 : 0

        return CashFlowAnalytics(
            income: income,
            expense: expense,
            netFlow: income - expense,
            savingsRate: savingsRate
        )
    }

    // MARK: - Period Comparison

    func monthOverMonth() throws -> PeriodComparison {
        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let startOfPrevMonth = cal.date(byAdding: .month, value: -1, to: startOfMonth)!

        let current = try repository.totalSpending(from: startOfMonth, to: now)
        let previous = try repository.totalSpending(from: startOfPrevMonth, to: startOfMonth)

        let change = previous > 0 ? ((current - previous) / previous) * 100 : 0
        let direction: TrendDirection = change > 2 ? .up : change < -2 ? .down : .flat

        return PeriodComparison(
            currentPeriod: current,
            previousPeriod: previous,
            changePercent: change,
            direction: direction
        )
    }
}
