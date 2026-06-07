import Foundation
import SwiftData

@MainActor
final class TransactionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ transaction: Transaction) throws {
        context.insert(transaction)
        try context.save()
    }

    func delete(_ transaction: Transaction) throws {
        context.delete(transaction)
        try context.save()
    }

    func fetchAll(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        category: String? = nil,
        merchant: String? = nil,
        type: TransactionType? = nil,
        limit: Int? = nil,
        sortBy: SortDescriptor<Transaction> = SortDescriptor(\.transactionDate, order: .reverse)
    ) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(sortBy: [sortBy])

        if let limit {
            descriptor.fetchLimit = limit
        }

        var results = try context.fetch(descriptor)

        // Filter in Swift (SwiftData compound predicates are limited)
        if let startDate {
            results = results.filter { $0.transactionDate >= startDate }
        }
        if let endDate {
            results = results.filter { $0.transactionDate <= endDate }
        }
        if let category {
            results = results.filter { $0.categoryName == category }
        }
        if let merchant {
            results = results.filter { $0.normalizedMerchant == merchant }
        }
        if let type {
            results = results.filter { $0.transactionType == type }
        }

        return results
    }

    func totalSpending(from startDate: Date, to endDate: Date) throws -> Double {
        let transactions = try fetchAll(from: startDate, to: endDate)
        return transactions
            .filter { $0.transactionType != .credit }
            .reduce(0) { $0 + $1.amount }
    }

    func totalIncome(from startDate: Date, to endDate: Date) throws -> Double {
        let transactions = try fetchAll(from: startDate, to: endDate)
        return transactions
            .filter { $0.transactionType == .credit }
            .reduce(0) { $0 + $1.amount }
    }

    func spendingByCategory(from startDate: Date, to endDate: Date) throws -> [String: Double] {
        let transactions = try fetchAll(from: startDate, to: endDate)
        var result: [String: Double] = [:]
        for t in transactions where t.transactionType != .credit {
            result[t.categoryName, default: 0] += t.amount
        }
        return result
    }

    func topMerchants(from startDate: Date, to endDate: Date, limit: Int = 10) throws -> [(String, Double)] {
        let transactions = try fetchAll(from: startDate, to: endDate)
        var merchantTotals: [String: Double] = [:]
        for t in transactions where t.transactionType != .credit {
            merchantTotals[t.normalizedMerchant, default: 0] += t.amount
        }
        return merchantTotals.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }
}
