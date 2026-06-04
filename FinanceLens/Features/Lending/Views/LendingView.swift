import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor
final class LendingViewModel: ObservableObject {
    @Published var lendings: [Lending] = []
    private var context: ModelContext?

    var totalLent: Double { lendings.filter { $0.type == .lent && !$0.isSettled }.reduce(0) { $0 + $1.remainingAmount } }
    var totalBorrowed: Double { lendings.filter { $0.type == .borrowed && !$0.isSettled }.reduce(0) { $0 + $1.remainingAmount } }
    var overdueCount: Int { lendings.filter(\.isOverdue).count }

    func setup(context: ModelContext) {
        self.context = context
        load()
    }

    func load() {
        guard let context else { return }
        let descriptor = FetchDescriptor<Lending>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        lendings = (try? context.fetch(descriptor)) ?? []
    }

    func add(_ lending: Lending) {
        context?.insert(lending)
        try? context?.save()
        load()
    }

    func delete(_ lending: Lending) {
        context?.delete(lending)
        try? context?.save()
        load()
    }

    func recordPayment(for lending: Lending, amount: Double, note: String = "") {
        let payment = LendingPayment(amount: amount, note: note)
        lending.payments.append(payment)
        lending.remainingAmount = max(0, lending.remainingAmount - amount)
        if lending.remainingAmount == 0 { lending.isSettled = true }
        try? context?.save()
        load()
    }

    func settle(_ lending: Lending) {
        lending.isSettled = true
        lending.remainingAmount = 0
        try? context?.save()
        load()
    }
}

// MARK: - List View

struct LendingListView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = LendingViewModel()
    @State private var showAdd = false
    @State private var selectedLending: Lending?
    @State private var filter: LendingFilter = .all

    enum LendingFilter: String, CaseIterable {
        case all = "All"
        case lent = "Lent"
        case borrowed = "Borrowed"
        case overdue = "Overdue"
    }

    var filteredList: [Lending] {
        switch filter {
        case .all: return viewModel.lendings.filter { !$0.isSettled }
        case .lent: return viewModel.lendings.filter { $0.type == .lent && !$0.isSettled }
        case .borrowed: return viewModel.lendings.filter { $0.type == .borrowed && !$0.isSettled }
        case .overdue: return viewModel.lendings.filter(\.isOverdue)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary
                HStack(spacing: 16) {
                    summaryCard("To Receive", value: viewModel.totalLent, color: .green)
                    summaryCard("To Pay", value: viewModel.totalBorrowed, color: .red)
                }
                .padding()

                Picker("Filter", selection: $filter) {
                    ForEach(LendingFilter.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    ForEach(filteredList, id: \.id) { lending in
                        LendingRow(lending: lending)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedLending = lending }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { viewModel.delete(filteredList[i]) }
                    }

                    if !viewModel.lendings.filter(\.isSettled).isEmpty {
                        Section("Settled") {
                            ForEach(viewModel.lendings.filter(\.isSettled), id: \.id) { lending in
                                LendingRow(lending: lending)
                                    .opacity(0.6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lendings & Loans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddLendingView(viewModel: viewModel) }
            .sheet(item: $selectedLending) { lending in
                LendingDetailView(lending: lending, viewModel: viewModel)
            }
            .onAppear { viewModel.setup(context: context) }
        }
    }

    private func summaryCard(_ title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("₹\(value, specifier: "%.0f")").font(.title3.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct LendingRow: View {
    let lending: Lending

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lending.personName).font(.headline)
                Text(lending.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(lending.type == .lent ? .green : .orange)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(lending.remainingAmount, specifier: "%.0f")")
                    .font(.subheadline.bold())
                if lending.isOverdue {
                    Text("OVERDUE").font(.caption2.bold()).foregroundStyle(.red)
                } else if let due = lending.dueDate {
                    Text("Due \(due, style: .date)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add View

struct AddLendingView: View {
    @ObservedObject var viewModel: LendingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var personName = ""
    @State private var amount = ""
    @State private var reason = ""
    @State private var type: LendingType = .lent
    @State private var date = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400 * 30)

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Person Name", text: $personName)
                }
                Section("Amount") {
                    TextField("₹ Amount", text: $amount).keyboardType(.decimalPad)
                }
                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("I Lent (gave)").tag(LendingType.lent)
                        Text("I Borrowed (took)").tag(LendingType.borrowed)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Details") {
                    TextField("Reason (optional)", text: $reason)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add Lending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = Double(amount), !personName.isEmpty else { return }
                        let lending = Lending(personName: personName, amount: amt, type: type,
                                             reason: reason, date: date, dueDate: hasDueDate ? dueDate : nil)
                        viewModel.add(lending)
                        dismiss()
                    }
                    .disabled(amount.isEmpty || personName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Detail View

struct LendingDetailView: View {
    let lending: Lending
    @ObservedObject var viewModel: LendingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var paymentAmount = ""
    @State private var paymentNote = ""
    @State private var showPayment = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(lending.type == .lent ? "Lent to" : "Borrowed from")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lending.personName).font(.headline)
                    }
                    HStack {
                        Text("Total").foregroundStyle(.secondary)
                        Spacer()
                        Text("₹\(lending.amount, specifier: "%.0f")")
                    }
                    HStack {
                        Text("Remaining").foregroundStyle(.secondary)
                        Spacer()
                        Text("₹\(lending.remainingAmount, specifier: "%.0f")").bold()
                            .foregroundStyle(lending.remainingAmount > 0 ? .red : .green)
                    }
                    ProgressView(value: lending.progressPercent / 100)
                        .tint(lending.isSettled ? .green : .blue)
                }

                if !lending.reason.isEmpty {
                    Section("Reason") { Text(lending.reason) }
                }

                Section("Dates") {
                    HStack { Text("Created"); Spacer(); Text(lending.date, style: .date) }
                    if let due = lending.dueDate {
                        HStack {
                            Text("Due"); Spacer()
                            Text(due, style: .date)
                                .foregroundStyle(lending.isOverdue ? .red : .primary)
                        }
                    }
                }

                if !lending.payments.isEmpty {
                    Section("Payment History") {
                        ForEach(lending.payments) { payment in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("₹\(payment.amount, specifier: "%.0f")").font(.subheadline.bold())
                                    if !payment.note.isEmpty {
                                        Text(payment.note).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(payment.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !lending.isSettled {
                    Section {
                        Button("Record Payment") { showPayment = true }
                        Button("Mark as Settled") {
                            viewModel.settle(lending)
                            dismiss()
                        }
                        .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Lending Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("Record Payment", isPresented: $showPayment) {
                TextField("Amount", text: $paymentAmount).keyboardType(.decimalPad)
                TextField("Note (optional)", text: $paymentNote)
                Button("Save") {
                    if let amt = Double(paymentAmount) {
                        viewModel.recordPayment(for: lending, amount: amt, note: paymentNote)
                        paymentAmount = ""
                        paymentNote = ""
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
    }
}
