import Foundation
import SwiftData

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Double
    var savedAmount: Double
    var deadline: Date?
    var icon: String
    var isCompleted: Bool
    var createdAt: Date

    init(name: String, targetAmount: Double, deadline: Date? = nil, icon: String = "star.fill") {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.savedAmount = 0
        self.deadline = deadline
        self.icon = icon
        self.isCompleted = false
        self.createdAt = .now
    }

    var progress: Double { targetAmount > 0 ? min(1.0, savedAmount / targetAmount) : 0 }
    var remaining: Double { max(0, targetAmount - savedAmount) }
    var daysLeft: Int? {
        guard let deadline else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0)
    }
    var dailyTarget: Double? {
        guard let days = daysLeft, days > 0 else { return nil }
        return remaining / Double(days)
    }
}
