import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var color: String
    var isDefault: Bool
    var keywords: [String]

    var transactions: [Transaction]?

    init(name: String, icon: String, color: String, isDefault: Bool = true, keywords: [String] = []) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
        self.keywords = keywords
    }

    static let defaults: [(String, String, String, [String])] = [
        ("Food", "fork.knife", "#FF6B6B", ["restaurant", "cafe", "food", "dining", "swiggy", "zomato", "dominos"]),
        ("Groceries", "cart.fill", "#4ECDC4", ["grocery", "bigbasket", "blinkit", "dmart", "supermarket"]),
        ("Fruits", "leaf.fill", "#66BB6A", ["fruit", "fruits", "mango", "apple", "banana", "organic", "juice"]),
        ("Fuel", "fuelpump.fill", "#45B7D1", ["petrol", "diesel", "fuel", "hp", "iocl", "bpcl"]),
        ("Utilities", "bolt.fill", "#96CEB4", ["electricity", "water", "gas", "internet", "broadband", "phone"]),
        ("Travel", "airplane", "#DDA0DD", ["flight", "hotel", "uber", "ola", "rapido", "irctc", "train"]),
        ("Shopping", "bag.fill", "#FFD93D", ["amazon", "flipkart", "myntra", "ajio", "mall"]),
        ("Entertainment", "film.fill", "#6C5CE7", ["netflix", "spotify", "movie", "theatre", "hotstar"]),
        ("Medical", "cross.case.fill", "#FF8A80", ["hospital", "pharmacy", "doctor", "medical", "apollo"]),
        ("Education", "book.fill", "#81C784", ["school", "college", "course", "udemy", "book"]),
        ("Investment", "chart.line.uptrend.xyaxis", "#64B5F6", ["mutual fund", "stock", "sip", "zerodha", "groww"]),
        ("Insurance", "shield.fill", "#FFB74D", ["insurance", "lic", "policy", "premium"]),
        ("EMI", "creditcard.fill", "#CE93D8", ["emi", "loan", "installment"]),
        ("Subscription", "repeat", "#4DB6AC", ["subscription", "membership", "premium"]),
        ("Rent", "house.fill", "#A1887F", ["rent", "lease", "housing"]),
        ("Salary", "banknote.fill", "#AED581", ["salary", "income", "credit"]),
        ("Miscellaneous", "ellipsis.circle.fill", "#90A4AE", [])
    ]
}
