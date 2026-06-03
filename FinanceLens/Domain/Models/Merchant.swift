import Foundation
import SwiftData

@Model
final class Merchant {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String
    var aliases: [String]
    var categoryName: String
    var totalSpent: Double
    var transactionCount: Int
    var transactions: [Transaction]?

    init(name: String, normalizedName: String, aliases: [String] = [], categoryName: String = "Miscellaneous") {
        self.id = UUID()
        self.name = name
        self.normalizedName = normalizedName
        self.aliases = aliases
        self.categoryName = categoryName
        self.totalSpent = 0
        self.transactionCount = 0
    }
}
