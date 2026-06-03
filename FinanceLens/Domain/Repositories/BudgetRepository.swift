import Foundation
import SwiftData

@MainActor
final class BudgetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ budget: Budget) throws {
        context.insert(budget)
        try context.save()
    }

    func delete(_ budget: Budget) throws {
        context.delete(budget)
        try context.save()
    }

    func fetchBudgets(month: Int, year: Int) throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.categoryName)]
        )
        let all = try context.fetch(descriptor)
        return all.filter { $0.month == month && $0.year == year }
    }

    func updateSpent(category: String, month: Int, year: Int, spent: Double) throws {
        let budgets = try fetchBudgets(month: month, year: year)
        if let budget = budgets.first(where: { $0.categoryName == category }) {
            budget.spent = spent
            try context.save()
        }
    }
}
