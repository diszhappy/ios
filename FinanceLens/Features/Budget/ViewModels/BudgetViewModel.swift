import SwiftUI
import SwiftData
import UserNotifications

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var currentMonth: Int
    @Published var currentYear: Int

    private var repository: BudgetRepository?
    private var transactionRepository: TransactionRepository?

    init() {
        let cal = Calendar.current
        let now = Date()
        self.currentMonth = cal.component(.month, from: now)
        self.currentYear = cal.component(.year, from: now)
    }

    func setup(context: ModelContext) {
        self.repository = BudgetRepository(context: context)
        self.transactionRepository = TransactionRepository(context: context)
        loadBudgets()
        recalculateSpending()
    }

    func loadBudgets() {
        guard let repository else { return }
        do {
            budgets = try repository.fetchBudgets(month: currentMonth, year: currentYear)
        } catch {
            print("Failed to load budgets: \(error)")
        }
    }

    func addBudget(category: String, amount: Double) {
        guard let repository else { return }
        let budget = Budget(categoryName: category, amount: amount, month: currentMonth, year: currentYear)
        do {
            try repository.save(budget)
            loadBudgets()
            recalculateSpending()
        } catch {
            print("Failed to save budget: \(error)")
        }
    }

    func deleteBudget(_ budget: Budget) {
        guard let repository else { return }
        do {
            try repository.delete(budget)
            loadBudgets()
        } catch {
            print("Failed to delete budget: \(error)")
        }
    }

    func recalculateSpending() {
        guard let transactionRepository, let repository else { return }
        let cal = Calendar.current
        guard let startOfMonth = cal.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)),
              let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) else { return }

        do {
            let spending = try transactionRepository.spendingByCategory(from: startOfMonth, to: endOfMonth)
            for budget in budgets {
                let spent = spending[budget.categoryName] ?? 0
                try repository.updateSpent(category: budget.categoryName, month: currentMonth, year: currentYear, spent: spent)
                checkAlerts(budget: budget, spent: spent)
            }
            loadBudgets()
        } catch {
            print("Failed to recalculate: \(error)")
        }
    }

    private func checkAlerts(budget: Budget, spent: Double) {
        let utilization = budget.amount > 0 ? (spent / budget.amount) * 100 : 0

        if utilization >= 100 && !budget.alertAt100 {
            budget.alertAt100 = true
            sendNotification(title: "Budget Exceeded!", body: "\(budget.categoryName) budget of ₹\(Int(budget.amount)) has been exceeded.")
        } else if utilization >= 80 && !budget.alertAt80 {
            budget.alertAt80 = true
            sendNotification(title: "Budget Warning", body: "\(budget.categoryName): 80% of ₹\(Int(budget.amount)) budget used.")
        } else if utilization >= 50 && !budget.alertAt50 {
            budget.alertAt50 = true
            sendNotification(title: "Budget Update", body: "\(budget.categoryName): 50% of ₹\(Int(budget.amount)) budget used.")
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    var totalBudget: Double { budgets.reduce(0) { $0 + $1.amount } }
    var totalSpent: Double { budgets.reduce(0) { $0 + $1.spent } }
    var totalRemaining: Double { max(0, totalBudget - totalSpent) }
}
