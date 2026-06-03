import SwiftUI

struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showAddBudget = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Budget")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("₹\(viewModel.totalBudget, specifier: "%.0f")")
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("₹\(viewModel.totalRemaining, specifier: "%.0f")")
                                .font(.title2.bold())
                                .foregroundStyle(viewModel.totalRemaining > 0 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Category Budgets") {
                    ForEach(viewModel.budgets, id: \.id) { budget in
                        BudgetRowView(budget: budget)
                    }
                    .onDelete { indexSet in
                        for i in indexSet { viewModel.deleteBudget(viewModel.budgets[i]) }
                    }
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddBudget = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView(viewModel: viewModel)
            }
            .onAppear { viewModel.setup(context: context) }
        }
    }
}

struct BudgetRowView: View {
    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.categoryName)
                    .font(.headline)
                Spacer()
                Text("₹\(budget.spent, specifier: "%.0f") / ₹\(budget.amount, specifier: "%.0f")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(budget.utilization / 100, 1.0))
                .tint(progressColor)

            if budget.isOverBudget {
                Text("Over by ₹\(budget.spent - budget.amount, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        switch budget.utilization {
        case 0..<50: return .green
        case 50..<80: return .yellow
        case 80..<100: return .orange
        default: return .red
        }
    }
}

struct AddBudgetView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = "Food"
    @State private var amount = ""

    private let categories = Category.defaults.map(\.0)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
                TextField("Budget Amount (₹)", text: $amount)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amt = Double(amount) {
                            viewModel.addBudget(category: selectedCategory, amount: amt)
                            dismiss()
                        }
                    }
                    .disabled(amount.isEmpty)
                }
            }
        }
    }
}
