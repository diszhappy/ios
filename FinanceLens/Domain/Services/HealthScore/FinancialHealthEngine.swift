import Foundation

struct FinancialHealthScore {
    let score: Int // 0-100
    let grade: HealthGrade
    let savingsRateScore: Double
    let consistencyScore: Double
    let budgetAdherenceScore: Double
    let subscriptionBurdenScore: Double
    let incomeStabilityScore: Double
    let strengths: [String]
    let weaknesses: [String]
    let recommendations: [String]
}

enum HealthGrade: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"

    static func from(score: Int) -> HealthGrade {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
}

@MainActor
final class FinancialHealthEngine {
    private let repository: TransactionRepository
    private let budgetRepository: BudgetRepository

    init(repository: TransactionRepository, budgetRepository: BudgetRepository) {
        self.repository = repository
        self.budgetRepository = budgetRepository
    }

    func calculateScore() throws -> FinancialHealthScore {
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now)!
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        let transactions = try repository.fetchAll(from: threeMonthsAgo, to: now)
        let income = transactions.filter { $0.transactionType == .credit }.reduce(0) { $0 + $1.amount }
        let expense = transactions.filter { $0.transactionType != .credit }.reduce(0) { $0 + $1.amount }

        // 1. Savings Rate (25 points)
        let savingsRate = income > 0 ? (income - expense) / income : 0
        let savingsScore = min(25.0, savingsRate * 100)

        // 2. Spending Consistency (20 points)
        let consistencyScore = calculateConsistency(transactions: transactions)

        // 3. Budget Adherence (25 points)
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)
        let budgets = try budgetRepository.fetchBudgets(month: month, year: year)
        let budgetScore = calculateBudgetAdherence(budgets: budgets)

        // 4. Subscription Burden (15 points)
        let subscriptionExpense = transactions.filter { $0.isRecurring }.reduce(0) { $0 + $1.amount }
        let subscriptionRatio = expense > 0 ? subscriptionExpense / expense : 0
        let subscriptionScore = max(0, 15.0 * (1.0 - subscriptionRatio * 2))

        // 5. Income Stability (15 points)
        let incomeScore = calculateIncomeStability(transactions: transactions)

        let totalScore = Int(savingsScore + consistencyScore + budgetScore + subscriptionScore + incomeScore)
        let clampedScore = max(0, min(100, totalScore))

        var strengths: [String] = []
        var weaknesses: [String] = []
        var recommendations: [String] = []

        if savingsScore > 15 { strengths.append("Good savings rate (\(Int(savingsRate * 100))%)") }
        else { weaknesses.append("Low savings rate"); recommendations.append("Try to save at least 20% of income") }

        if budgetScore > 18 { strengths.append("Excellent budget discipline") }
        else if !budgets.isEmpty { weaknesses.append("Frequently exceeding budgets"); recommendations.append("Review and adjust budget limits") }

        if subscriptionScore > 10 { strengths.append("Subscriptions well managed") }
        else { weaknesses.append("High subscription burden"); recommendations.append("Review and cancel unused subscriptions") }

        if consistencyScore > 15 { strengths.append("Consistent spending patterns") }
        else { weaknesses.append("Irregular spending"); recommendations.append("Create a weekly spending plan") }

        return FinancialHealthScore(
            score: clampedScore,
            grade: HealthGrade.from(score: clampedScore),
            savingsRateScore: savingsScore,
            consistencyScore: consistencyScore,
            budgetAdherenceScore: budgetScore,
            subscriptionBurdenScore: subscriptionScore,
            incomeStabilityScore: incomeScore,
            strengths: strengths,
            weaknesses: weaknesses,
            recommendations: recommendations
        )
    }

    private func calculateConsistency(transactions: [Transaction]) -> Double {
        let cal = Calendar.current
        var weeklyTotals: [Int: Double] = [:]
        for t in transactions where t.transactionType != .credit {
            let week = cal.component(.weekOfYear, from: t.transactionDate)
            weeklyTotals[week, default: 0] += t.amount
        }
        guard weeklyTotals.count > 1 else { return 10 }

        let values = Array(weeklyTotals.values)
        let avg = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
        let cv = avg > 0 ? sqrt(variance) / avg : 1 // coefficient of variation

        return max(0, min(20, 20 * (1.0 - cv)))
    }

    private func calculateBudgetAdherence(budgets: [Budget]) -> Double {
        guard !budgets.isEmpty else { return 12.5 } // neutral if no budgets set
        let adherent = budgets.filter { !$0.isOverBudget }.count
        return 25.0 * (Double(adherent) / Double(budgets.count))
    }

    private func calculateIncomeStability(transactions: [Transaction]) -> Double {
        let cal = Calendar.current
        var monthlyIncome: [Int: Double] = [:]
        for t in transactions where t.transactionType == .credit {
            let month = cal.component(.month, from: t.transactionDate)
            monthlyIncome[month, default: 0] += t.amount
        }
        guard monthlyIncome.count > 1 else { return 7.5 }

        let values = Array(monthlyIncome.values)
        let avg = values.reduce(0, +) / Double(values.count)
        let cv = avg > 0 ? sqrt(values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)) / avg : 1

        return max(0, min(15, 15 * (1.0 - cv)))
    }
}
