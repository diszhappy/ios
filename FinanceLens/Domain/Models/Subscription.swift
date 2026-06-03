import Foundation
import SwiftData

@Model
final class Subscription {
    @Attribute(.unique) var id: UUID
    var name: String
    var merchant: String
    var amount: Double
    var frequency: SubscriptionFrequency
    var startDate: Date
    var nextDueDate: Date?
    var isActive: Bool
    var categoryName: String
    var transactions: [Transaction]?
    var createdAt: Date

    init(name: String, merchant: String, amount: Double, frequency: SubscriptionFrequency,
         startDate: Date, categoryName: String = "Subscription") {
        self.id = UUID()
        self.name = name
        self.merchant = merchant
        self.amount = amount
        self.frequency = frequency
        self.startDate = startDate
        self.isActive = true
        self.categoryName = categoryName
        self.createdAt = .now
        self.nextDueDate = frequency.nextDate(from: startDate)
    }

    var monthlyEquivalent: Double {
        switch frequency {
        case .weekly: return amount * 4.33
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .yearly: return amount / 12
        }
    }
}

enum SubscriptionFrequency: String, Codable, CaseIterable {
    case weekly, monthly, quarterly, yearly

    func nextDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
