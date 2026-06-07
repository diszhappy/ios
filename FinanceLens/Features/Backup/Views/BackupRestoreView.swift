import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export Service

@MainActor
final class BackupService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    struct BackupData: Codable {
        let version: Int
        let exportDate: Date
        let transactions: [TransactionDTO]
        let budgets: [BudgetDTO]
        let lendings: [LendingDTO]
    }

    struct TransactionDTO: Codable {
        let amount: Double
        let merchant: String
        let normalizedMerchant: String
        let categoryName: String
        let transactionDate: Date
        let transactionType: String
        let paymentMethod: String
        let notes: String
        let isRecurring: Bool
        let source: String
    }

    struct BudgetDTO: Codable {
        let categoryName: String
        let amount: Double
        let spent: Double
        let month: Int
        let year: Int
    }

    struct LendingDTO: Codable {
        let personName: String
        let amount: Double
        let remainingAmount: Double
        let type: String
        let reason: String
        let date: Date
        let dueDate: Date?
        let isSettled: Bool
    }

    func exportBackup() throws -> Data {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let lendings = (try? context.fetch(FetchDescriptor<Lending>())) ?? []

        let backup = BackupData(
            version: 1,
            exportDate: .now,
            transactions: transactions.map {
                TransactionDTO(amount: $0.amount, merchant: $0.merchant,
                    normalizedMerchant: $0.normalizedMerchant, categoryName: $0.categoryName,
                    transactionDate: $0.transactionDate, transactionType: $0.transactionType.rawValue,
                    paymentMethod: $0.paymentMethod.rawValue, notes: $0.notes,
                    isRecurring: $0.isRecurring, source: $0.source.rawValue)
            },
            budgets: budgets.map {
                BudgetDTO(categoryName: $0.categoryName, amount: $0.amount, spent: $0.spent, month: $0.month, year: $0.year)
            },
            lendings: lendings.map {
                LendingDTO(personName: $0.personName, amount: $0.amount, remainingAmount: $0.remainingAmount,
                    type: $0.type.rawValue, reason: $0.reason, date: $0.date, dueDate: $0.dueDate, isSettled: $0.isSettled)
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(backup)
    }

    func importBackup(data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        var count = 0

        for dto in backup.transactions {
            let t = Transaction(
                amount: dto.amount, merchant: dto.merchant, normalizedMerchant: dto.normalizedMerchant,
                categoryName: dto.categoryName, transactionDate: dto.transactionDate,
                transactionType: TransactionType(rawValue: dto.transactionType) ?? .debit,
                paymentMethod: PaymentMethod(rawValue: dto.paymentMethod) ?? .other,
                notes: dto.notes, isRecurring: dto.isRecurring,
                source: TransactionSource(rawValue: dto.source) ?? .manual
            )
            context.insert(t)
            count += 1
        }

        for dto in backup.budgets {
            let b = Budget(categoryName: dto.categoryName, amount: dto.amount, month: dto.month, year: dto.year)
            b.spent = dto.spent
            context.insert(b)
        }

        for dto in backup.lendings {
            let l = Lending(personName: dto.personName, amount: dto.amount,
                type: LendingType(rawValue: dto.type) ?? .lent, reason: dto.reason,
                date: dto.date, dueDate: dto.dueDate)
            l.remainingAmount = dto.remainingAmount
            l.isSettled = dto.isSettled
            context.insert(l)
        }

        try context.save()
        return count
    }
}

// MARK: - Backup View

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var context
    @State private var showExportShare = false
    @State private var showImportPicker = false
    @State private var exportURL: URL?
    @State private var message: String?

    var body: some View {
        List {
            Section("Export") {
                Button("Export Backup") { exportData() }
                Text("Saves all transactions, budgets, and lendings as JSON")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Restore") {
                Button("Import Backup") { showImportPicker = true }
                Text("Restores data from a previously exported backup file")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
        }
        .navigationTitle("Backup & Restore")
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { importData(url: url) }
        }
    }

    private func exportData() {
        let service = BackupService(context: context)
        guard let data = try? service.exportBackup() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FinanceLens_Backup_\(Date.now.formatted(.dateTime.year().month().day())).json")
        try? data.write(to: url)
        exportURL = url
        showExportShare = true
    }

    private func importData(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let service = BackupService(context: context)
        guard let data = try? Data(contentsOf: url),
              let count = try? service.importBackup(data: data) else {
            message = "Import failed"
            return
        }
        message = "Restored \(count) transactions successfully"
    }
}
