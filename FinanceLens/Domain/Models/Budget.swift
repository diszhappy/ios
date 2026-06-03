import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var categoryName: String
    var amount: Double
    var spent: Double
    var month: Int
    var year: Int
    var alertAt50: Bool
    var alertAt80: Bool
    var alertAt100: Bool
    var createdAt: Date

    init(categoryName: String, amount: Double, month: Int, year: Int) {
        self.id = UUID()
        self.categoryName = categoryName
        self.amount = amount
        self.spent = 0
        self.month = month
        self.year = year
        self.alertAt50 = false
        self.alertAt80 = false
        self.alertAt100 = false
        self.createdAt = .now
    }

    var utilization: Double {
        guard amount > 0 else { return 0 }
        return (spent / amount) * 100
    }

    var remaining: Double {
        max(0, amount - spent)
    }

    var isOverBudget: Bool {
        spent > amount
    }
}
