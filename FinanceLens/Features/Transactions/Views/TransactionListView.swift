import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showAddTransaction = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredTransactions, id: \.id) { transaction in
                    TransactionRowView(transaction: transaction)
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
            .onAppear { viewModel.setup(context: context) }
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
