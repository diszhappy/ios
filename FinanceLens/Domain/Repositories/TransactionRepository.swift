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
        sortBy: SortDescriptor<Transaction> = SortDescriptor(\.transactionDate, order: .reverse)
    ) throws -> [Transaction] {
        var predicates: [Predicate<Transaction>] = []

        if let startDate {
            predicates.append(#Predicate { $0.transactionDate >= startDate })
        }
        if let endDate {
            predicates.append(#Predicate { $0.transactionDate <= endDate })
        }
        if let category {
            predicates.append(#Predicate { $0.categoryName == category })
        }
        if let merchant {
            predicates.append(#Predicate { $0.normalizedMerchant == merchant })
        }

        let descriptor = FetchDescriptor<Transaction>(sortBy: [sortBy])
        var results = try context.fetch(descriptor)

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
