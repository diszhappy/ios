import SwiftUI

struct AddTransactionView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var merchant = ""
    @State private var notes = ""
    @State private var selectedCategory = "Miscellaneous"
    @State private var selectedType: TransactionType = .debit
    @State private var selectedPayment: PaymentMethod = .upi
    @State private var date = Date()
    @State private var time = Date()

    private let categories = Category.defaults.map(\.0)

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("₹ Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("Details") {
                    TextField("Merchant", text: $merchant)
                    TextField("Notes (optional)", text: $notes)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                }

                Section("Type") {
                    Picker("Transaction Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Payment Method") {
                    Picker("Method", selection: $selectedPayment) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.rawValue.capitalized).tag(method)
                        }
                    }
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTransaction() }
                        .disabled(amount.isEmpty || merchant.isEmpty)
                }
            }
        }
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let combinedDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                         minute: timeComponents.minute ?? 0,
                                         second: 0, of: date) ?? date
        let transaction = Transaction(
            amount: amountValue,
            merchant: merchant,
            categoryName: selectedCategory,
            transactionDate: combinedDate,
            transactionType: selectedType,
            paymentMethod: selectedPayment,
            notes: notes,
            source: .manual
        )
        viewModel.addTransaction(transaction)
        dismiss()
    }
}
