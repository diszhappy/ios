import Foundation
import NaturalLanguage
import SwiftData

// MARK: - Query Types

enum FinancialQueryType {
    case spending(category: String?, merchant: String?, period: DateRange?)
    case comparison(period1: DateRange, period2: DateRange)
    case subscription
    case budget
    case forecast
    case healthScore
    case search(query: String)
    case general(question: String)
}

struct DateRange {
    let start: Date
    let end: Date

    static var thisMonth: DateRange {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        return DateRange(start: start, end: now)
    }

    static var lastMonth: DateRange {
        let cal = Calendar.current
        let now = Date()
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let start = cal.date(byAdding: .month, value: -1, to: startOfThisMonth)!
        return DateRange(start: start, end: startOfThisMonth)
    }
}

// MARK: - Query Interpreter

final class FinancialQueryInterpreter {
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    private let merchantEngine = MerchantRecognitionEngine()

    func interpret(_ query: String) -> FinancialQueryType {
        let lower = query.lowercased()

        // Subscription queries
        if lower.contains("subscription") || lower.contains("recurring") {
            return .subscription
        }

        // Budget queries
        if lower.contains("budget") || lower.contains("remaining budget") {
            return .budget
        }

        // Forecast queries
        if lower.contains("predict") || lower.contains("forecast") || lower.contains("next month") || lower.contains("end of month") {
            return .forecast
        }

        // Health score
        if lower.contains("health") || lower.contains("score") || lower.contains("financial health") {
            return .healthScore
        }

        // Spending queries
        let period = extractPeriod(from: lower)
        let category = extractCategory(from: lower)
        let merchant = extractMerchant(from: lower)

        if lower.contains("spend") || lower.contains("spent") || lower.contains("expense") ||
           lower.contains("how much") || lower.contains("total") || lower.contains("show") {
            return .spending(category: category, merchant: merchant, period: period)
        }

        // Comparison
        if lower.contains("compare") || lower.contains("vs") || lower.contains("increase") || lower.contains("decrease") {
            return .comparison(period1: period ?? .lastMonth, period2: .thisMonth)
        }

        // Search
        if lower.contains("find") || lower.contains("search") || lower.contains("above") || lower.contains("below") {
            return .search(query: query)
        }

        return .general(question: query)
    }

    private func extractPeriod(from text: String) -> DateRange? {
        if text.contains("last month") || text.contains("previous month") { return .lastMonth }
        if text.contains("this month") || text.contains("current month") { return .thisMonth }

        // Extract specific month names
        let months = ["january", "february", "march", "april", "may", "june",
                      "july", "august", "september", "october", "november", "december"]
        for (i, month) in months.enumerated() {
            if text.contains(month) {
                let cal = Calendar.current
                let year = cal.component(.year, from: Date())
                let start = cal.date(from: DateComponents(year: year, month: i + 1, day: 1))!
                let end = cal.date(byAdding: .month, value: 1, to: start)!
                return DateRange(start: start, end: end)
            }
        }
        return nil
    }

    private func extractCategory(from text: String) -> String? {
        let categories = Category.defaults.map { ($0.0.lowercased(), $0.0) }
        for (lower, original) in categories {
            if text.contains(lower) { return original }
        }
        return nil
    }

    private func extractMerchant(from text: String) -> String? {
        let normalized = merchantEngine.normalize(text)
        return normalized != text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
            ? normalized : nil
    }
}

// MARK: - Context Builder

@MainActor
final class FinancialContextBuilder {
    private let repository: TransactionRepository
    private let budgetRepository: BudgetRepository

    init(repository: TransactionRepository, budgetRepository: BudgetRepository) {
        self.repository = repository
        self.budgetRepository = budgetRepository
    }

    func buildContext(for queryType: FinancialQueryType) throws -> String {
        switch queryType {
        case .spending(let category, let merchant, let period):
            return try buildSpendingContext(category: category, merchant: merchant, period: period ?? .thisMonth)
        case .comparison(let p1, let p2):
            return try buildComparisonContext(period1: p1, period2: p2)
        case .subscription:
            return try buildSubscriptionContext()
        case .budget:
            return try buildBudgetContext()
        case .forecast:
            return try buildForecastContext()
        case .healthScore:
            return try buildHealthContext()
        case .search(let query):
            return try buildSearchContext(query: query)
        case .general:
            return try buildGeneralContext()
        }
    }

    private func buildSpendingContext(category: String?, merchant: String?, period: DateRange) throws -> String {
        var context = "Period: \(formatDate(period.start)) to \(formatDate(period.end))\n"

        if let category {
            let spending = try repository.spendingByCategory(from: period.start, to: period.end)
            context += "Category '\(category)': ₹\(Int(spending[category] ?? 0))\n"
            let transactions = try repository.fetchAll(from: period.start, to: period.end, category: category)
            context += "Transactions: \(transactions.count)\n"
            for t in transactions.prefix(10) {
                context += "  - \(t.merchant): ₹\(Int(t.amount)) on \(formatDate(t.transactionDate))\n"
            }
        } else if let merchant {
            let transactions = try repository.fetchAll(from: period.start, to: period.end, merchant: merchant)
            let total = transactions.reduce(0) { $0 + $1.amount }
            context += "Merchant '\(merchant)': ₹\(Int(total)) across \(transactions.count) transactions\n"
            for t in transactions.prefix(10) {
                context += "  - ₹\(Int(t.amount)) on \(formatDate(t.transactionDate))\n"
            }
        } else {
            let total = try repository.totalSpending(from: period.start, to: period.end)
            let income = try repository.totalIncome(from: period.start, to: period.end)
            context += "Total Spending: ₹\(Int(total))\nTotal Income: ₹\(Int(income))\nSavings: ₹\(Int(income - total))\n"
            let byCategory = try repository.spendingByCategory(from: period.start, to: period.end)
            context += "By Category:\n"
            for (cat, amt) in byCategory.sorted(by: { $0.value > $1.value }).prefix(8) {
                context += "  - \(cat): ₹\(Int(amt))\n"
            }
        }
        return context
    }

    private func buildComparisonContext(period1: DateRange, period2: DateRange) throws -> String {
        let spending1 = try repository.totalSpending(from: period1.start, to: period1.end)
        let spending2 = try repository.totalSpending(from: period2.start, to: period2.end)
        let change = spending1 > 0 ? ((spending2 - spending1) / spending1) * 100 : 0

        return """
        Previous period: ₹\(Int(spending1))
        Current period: ₹\(Int(spending2))
        Change: \(change > 0 ? "+" : "")\(Int(change))%
        """
    }

    private func buildSubscriptionContext() throws -> String {
        let transactions = try repository.fetchAll()
        let detector = SubscriptionDetectionEngine()
        let subs = detector.detect(transactions: transactions)
        var context = "Detected Subscriptions:\n"
        let totalMonthly = subs.reduce(0.0) { $0 + Subscription(name: $1.merchant, merchant: $1.merchant, amount: $1.averageAmount, frequency: $1.frequency, startDate: $1.lastDate).monthlyEquivalent }
        context += "Total Monthly Cost: ₹\(Int(totalMonthly))\n"
        for sub in subs {
            context += "  - \(sub.merchant): ₹\(Int(sub.averageAmount)) (\(sub.frequency.rawValue))\n"
        }
        return context
    }

    private func buildBudgetContext() throws -> String {
        let cal = Calendar.current
        let now = Date()
        let budgets = try budgetRepository.fetchBudgets(month: cal.component(.month, from: now), year: cal.component(.year, from: now))
        var context = "Current Month Budgets:\n"
        for b in budgets {
            context += "  - \(b.categoryName): ₹\(Int(b.spent))/₹\(Int(b.amount)) (\(Int(b.utilization))%)\n"
        }
        return context
    }

    private func buildForecastContext() throws -> String {
        let engine = ForecastingEngine(repository: repository)
        let monthly = try engine.forecastMonthlySpending()
        let endOfMonth = try engine.forecastEndOfMonth()
        return """
        Forecast:
        Next month spending: ₹\(Int(monthly.predictedValue)) (confidence: \(Int(monthly.confidence * 100))%)
        End of this month: ₹\(Int(endOfMonth.predictedValue)) (confidence: \(Int(endOfMonth.confidence * 100))%)
        """
    }

    private func buildHealthContext() throws -> String {
        let engine = FinancialHealthEngine(repository: repository, budgetRepository: budgetRepository)
        let score = try engine.calculateScore()
        return """
        Financial Health Score: \(score.score)/100 (\(score.grade.rawValue))
        Strengths: \(score.strengths.joined(separator: ", "))
        Weaknesses: \(score.weaknesses.joined(separator: ", "))
        Recommendations: \(score.recommendations.joined(separator: "; "))
        """
    }

    private func buildSearchContext(query: String) throws -> String {
        let transactions = try repository.fetchAll()
        let lower = query.lowercased()

        // Extract amount threshold
        var filtered = transactions
        if let amountMatch = lower.range(of: #"above ₹?(\d+)"#, options: .regularExpression) {
            let numStr = String(lower[amountMatch]).filter { $0.isNumber }
            if let threshold = Double(numStr) {
                filtered = filtered.filter { $0.amount > threshold }
            }
        }

        var context = "Search results (\(filtered.count) transactions):\n"
        for t in filtered.prefix(15) {
            context += "  - \(t.merchant): ₹\(Int(t.amount)) [\(t.categoryName)] \(formatDate(t.transactionDate))\n"
        }
        return context
    }

    private func buildGeneralContext() throws -> String {
        let period = DateRange.thisMonth
        let total = try repository.totalSpending(from: period.start, to: period.end)
        let income = try repository.totalIncome(from: period.start, to: period.end)
        return "This month: Income ₹\(Int(income)), Expenses ₹\(Int(total)), Savings ₹\(Int(income - total))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Chat Engine

@MainActor
final class FinancialChatEngine: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false

    private let interpreter = FinancialQueryInterpreter()
    private var contextBuilder: FinancialContextBuilder?
    private var modelContext: ModelContext?

    func setup(context: ModelContext) {
        self.modelContext = context
        let repo = TransactionRepository(context: context)
        let budgetRepo = BudgetRepository(context: context)
        self.contextBuilder = FinancialContextBuilder(repository: repo, budgetRepository: budgetRepo)
    }

    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(content: text, role: .user)
        messages.append(userMessage)
        isProcessing = true

        let queryType = interpreter.interpret(text)

        do {
            let context = try contextBuilder?.buildContext(for: queryType) ?? ""
            let response = generateResponse(query: text, queryType: queryType, context: context)
            let assistantMessage = ChatMessage(content: response, role: .assistant, sources: ["Local Data"])
            messages.append(assistantMessage)
        } catch {
            let errorMessage = ChatMessage(content: "I couldn't process that query. Please try rephrasing.", role: .assistant)
            messages.append(errorMessage)
        }

        isProcessing = false
    }

    private func generateResponse(query: String, queryType: FinancialQueryType, context: String) -> String {
        switch queryType {
        case .spending:
            return "Here's what I found:\n\n\(context)"
        case .comparison:
            return "Here's the comparison:\n\n\(context)"
        case .subscription:
            return "Here are your detected subscriptions:\n\n\(context)"
        case .budget:
            return "Here's your budget status:\n\n\(context)"
        case .forecast:
            return "Here are the spending predictions:\n\n\(context)"
        case .healthScore:
            return "Here's your financial health assessment:\n\n\(context)"
        case .search:
            return "Search results:\n\n\(context)"
        case .general:
            return "Based on your financial data:\n\n\(context)\n\nTry asking about specific categories, merchants, budgets, subscriptions, or forecasts for more detailed insights."
        }
    }

    func clearHistory() {
        messages.removeAll()
    }
}
