import SwiftUI
import SwiftData

@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var selectedType: TransactionType?
    @Published var dateRange: ClosedRange<Date>?

    private var repository: TransactionRepository?

    func setup(context: ModelContext) {
        self.repository = TransactionRepository(context: context)
        loadTransactions()
    }

    func loadTransactions() {
        guard let repository else { return }
        do {
            transactions = try repository.fetchAll(
                from: dateRange?.lowerBound,
                to: dateRange?.upperBound,
                category: selectedCategory,
                type: selectedType,
                limit: 100
            )
        } catch {
            print("Failed to load transactions: \(error)")
        }
    }

    func addTransaction(_ transaction: Transaction) {
        guard let repository else { return }
        do {
            try repository.save(transaction)
            loadTransactions()
        } catch {
            print("Failed to save transaction: \(error)")
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        guard let repository else { return }
        do {
            try repository.delete(transaction)
            loadTransactions()
        } catch {
            print("Failed to delete transaction: \(error)")
        }
    }

    var filteredTransactions: [Transaction] {
        guard !searchText.isEmpty else { return transactions }
        let query = searchText.lowercased()
        return transactions.filter {
            $0.merchant.lowercased().contains(query) ||
            $0.categoryName.lowercased().contains(query) ||
            $0.notes.lowercased().contains(query)
        }
    }
}
