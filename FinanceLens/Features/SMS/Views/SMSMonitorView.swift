import SwiftUI
import SwiftData

struct SMSMonitorView: View {
    @Environment(\.modelContext) private var context
    @State private var smsText = ""
    @State private var parsedRecords: [ParsedSMS] = []
    @State private var editingRecord: ParsedSMS?
    @AppStorage("smsMonitorEnabled") private var smsMonitorEnabled = false

    private let parser = SMSParserEngine()

    var body: some View {
        NavigationStack {
            List {
                Section("Paste Bank SMS") {
                    TextEditor(text: $smsText)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if smsText.isEmpty {
                                    Text("Paste your bank SMS here...")
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            }, alignment: .topLeading
                        )

                    Button("Parse SMS") {
                        guard !smsText.isEmpty else { return }
                        let parsed = parser.parse(smsText)
                        parsedRecords.insert(parsed, at: 0)
                        smsText = ""
                    }
                    .disabled(smsText.isEmpty)
                }

                if !parsedRecords.isEmpty {
                    Section("Parsed Records (\(parsedRecords.count))") {
                        ForEach(parsedRecords, id: \.id) { record in
                            SMSRecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture { editingRecord = record }
                        }
                        .onDelete { indexSet in
                            parsedRecords.remove(atOffsets: indexSet)
                        }
                    }

                    Section {
                        Button("Save All Confirmed") {
                            saveConfirmed()
                        }
                        .disabled(parsedRecords.filter(\.isConfirmed).isEmpty)
                    }
                }
            }
            .navigationTitle("SMS Transactions")
            .sheet(item: $editingRecord) { record in
                EditSMSRecordView(record: record) { updated in
                    if let idx = parsedRecords.firstIndex(where: { $0.id == updated.id }) {
                        parsedRecords[idx] = updated
                    }
                }
            }
        }
    }

    private func saveConfirmed() {
        let confirmed = parsedRecords.filter(\.isConfirmed)
        for record in confirmed {
            if let transaction = record.toTransaction() {
                context.insert(transaction)
            }
        }
        try? context.save()
        parsedRecords.removeAll(where: \.isConfirmed)
    }
}

struct SMSRecordRow: View {
    let record: ParsedSMS

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.merchant ?? "Unknown Merchant")
                    .font(.subheadline.bold())
                Text(record.rawText.prefix(60) + "...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let amount = record.amount {
                    Text("\(record.type == .credit ? "+" : "-")₹\(amount, specifier: "%.0f")")
                        .font(.subheadline.bold())
                        .foregroundStyle(record.type == .credit ? .green : .red)
                } else {
                    Text("No amount")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Image(systemName: record.isConfirmed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(record.isConfirmed ? .green : .gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit View

struct EditSMSRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var merchant: String
    @State private var type: TransactionType
    @State private var date: Date
    @State private var isConfirmed: Bool

    private let recordId: UUID
    private let onSave: (ParsedSMS) -> Void
    private let rawText: String
    private let accountSuffix: String?
    private let referenceNumber: String?

    init(record: ParsedSMS, onSave: @escaping (ParsedSMS) -> Void) {
        self.recordId = record.id
        self.rawText = record.rawText
        self.accountSuffix = record.accountSuffix
        self.referenceNumber = record.referenceNumber
        self.onSave = onSave
        _amount = State(initialValue: record.amount.map { String(format: "%.2f", $0) } ?? "")
        _merchant = State(initialValue: record.merchant ?? "")
        _type = State(initialValue: record.type)
        _date = State(initialValue: record.date)
        _isConfirmed = State(initialValue: record.isConfirmed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Original SMS") {
                    Text(rawText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Parsed Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Merchant", text: $merchant)
                    Picker("Type", selection: $type) {
                        Text("Debit").tag(TransactionType.debit)
                        Text("Credit").tag(TransactionType.credit)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Date", selection: $date)
                }

                if let acc = accountSuffix {
                    Section("Account") {
                        Text("A/c ending \(acc)")
                    }
                }

                Section {
                    Toggle("Confirm for saving", isOn: $isConfirmed)
                }
            }
            .navigationTitle("Edit Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let updated = ParsedSMS(
                            id: recordId,
                            rawText: rawText,
                            amount: Double(amount),
                            merchant: merchant.isEmpty ? nil : merchant,
                            type: type,
                            accountSuffix: accountSuffix,
                            date: date,
                            referenceNumber: referenceNumber,
                            isConfirmed: isConfirmed
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}


