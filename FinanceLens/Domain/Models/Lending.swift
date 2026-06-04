import Foundation
import SwiftData

@Model
final class Lending {
    @Attribute(.unique) var id: UUID
    var personName: String
    var amount: Double
    var remainingAmount: Double
    var type: LendingType
    var reason: String
    var date: Date
    var dueDate: Date?
    var isSettled: Bool
    var payments: [LendingPayment]
    var createdAt: Date

    init(personName: String, amount: Double, type: LendingType, reason: String = "",
         date: Date = .now, dueDate: Date? = nil) {
        self.id = UUID()
        self.personName = personName
        self.amount = amount
        self.remainingAmount = amount
        self.type = type
        self.reason = reason
        self.date = date
        self.dueDate = dueDate
        self.isSettled = false
        self.payments = []
        self.createdAt = .now
    }

    var paidAmount: Double { amount - remainingAmount }
    var progressPercent: Double { amount > 0 ? (paidAmount / amount) * 100 : 0 }
    var isOverdue: Bool { !isSettled && (dueDate ?? .distantFuture) < .now }
}

enum LendingType: String, Codable, CaseIterable {
    case lent = "Lent"        // I gave money to someone
    case borrowed = "Borrowed" // I took money from someone
}

struct LendingPayment: Codable, Identifiable {
    let id: UUID
    let amount: Double
    let date: Date
    let note: String

    init(amount: Double, date: Date = .now, note: String = "") {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.note = note
    }
}
