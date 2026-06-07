import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showAddTransaction = false
    @State private var selectedTransaction: Transaction?

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredTransactions, id: \.id) { transaction in
                    TransactionRowView(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTransaction = transaction }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteTransaction(viewModel.filteredTransactions[index])
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search transactions")
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(viewModel: viewModel)
            }
            .sheet(item: $selectedTransaction) { txn in
                TransactionDetailView(transaction: txn)
            }
            .onAppear { viewModel.setup(context: context) }
        }
    }
}

// MARK: - Detail Popup

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Amount") {
                    HStack {
                        Text(transaction.transactionType == .credit ? "Credit" : "Debit")
                            .foregroundStyle(transaction.transactionType == .credit ? .green : .red)
                        Spacer()
                        Text("₹\(transaction.amount, specifier: "%.2f")")
                            .font(.title2.bold())
                    }
                }

                Section("Details") {
                    row("Merchant", transaction.merchant)
                    row("Normalized", transaction.normalizedMerchant)
                    row("Category", transaction.categoryName)
                    row("Date", transaction.transactionDate.formatted(date: .long, time: .shortened))
                    row("Payment", transaction.paymentMethod.rawValue.capitalized)
                    row("Type", transaction.transactionType.rawValue.capitalized)
                    row("Source", transaction.source.rawValue.capitalized)
                }

                if !transaction.notes.isEmpty {
                    Section("Notes") {
                        Text(transaction.notes)
                    }
                }

                Section("Metadata") {
                    row("Confidence", "\(Int(transaction.confidence * 100))%")
                    row("Recurring", transaction.isRecurring ? "Yes" : "No")
                    if let balance = transaction.balanceAfter {
                        row("Balance After", "₹\(balance, default: "%.2f")")
                    }
                    row("Created", transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.headline)
                Text(transaction.categoryName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.transactionType == .credit ? "+₹\(transaction.amount, specifier: "%.0f")" : "-₹\(transaction.amount, specifier: "%.0f")")
                    .font(.headline)
                    .foregroundStyle(transaction.transactionType == .credit ? .green : .primary)
                Text(transaction.transactionDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
