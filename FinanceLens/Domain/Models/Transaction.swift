import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var currency: String
    var merchant: String
    var normalizedMerchant: String
    var categoryName: String
    var transactionDate: Date
    var transactionType: TransactionType
    var paymentMethod: PaymentMethod
    var notes: String
    var isRecurring: Bool
    var confidence: Double
    var source: TransactionSource
    var balanceAfter: Double?

    @Relationship(inverse: \Category.transactions)
    var category: Category?

    @Relationship(inverse: \Merchant.transactions)
    var merchantEntity: Merchant?

    @Relationship(inverse: \Subscription.transactions)
    var subscription: Subscription?

    var createdAt: Date
    var updatedAt: Date

    init(
        amount: Double,
        currency: String = "INR",
        merchant: String,
        normalizedMerchant: String = "",
        categoryName: String = "Miscellaneous",
        transactionDate: Date = .now,
        transactionType: TransactionType = .debit,
        paymentMethod: PaymentMethod = .card,
        notes: String = "",
        isRecurring: Bool = false,
        confidence: Double = 1.0,
        source: TransactionSource = .manual,
        balanceAfter: Double? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.normalizedMerchant = normalizedMerchant.isEmpty ? merchant : normalizedMerchant
        self.categoryName = categoryName
        self.transactionDate = transactionDate
        self.transactionType = transactionType
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.isRecurring = isRecurring
        self.confidence = confidence
        self.source = source
        self.balanceAfter = balanceAfter
        self.createdAt = .now
        self.updatedAt = .now
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case debit, credit, upi, card, cash, bankTransfer, subscription
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash, card, upi, netBanking, wallet, bankTransfer, other
}

enum TransactionSource: String, Codable, CaseIterable {
    case manual, pdfImport, csvImport, txtImport, ocr
}
