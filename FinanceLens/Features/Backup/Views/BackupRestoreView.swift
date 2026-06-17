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
        var tDescriptor = FetchDescriptor<Transaction>()
        tDescriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        let transactions = (try? context.fetch(tDescriptor)) ?? []

        var bDescriptor = FetchDescriptor<Budget>()
        bDescriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        let budgets = (try? context.fetch(bDescriptor)) ?? []

        var lDescriptor = FetchDescriptor<Lending>()
        lDescriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        let lendings = (try? context.fetch(lDescriptor)) ?? []

        let transactionDTOs = transactions.map { t in
            TransactionDTO(amount: t.amount, merchant: t.merchant,
                normalizedMerchant: t.normalizedMerchant, categoryName: t.categoryName,
                transactionDate: t.transactionDate, transactionType: t.transactionType.rawValue,
                paymentMethod: t.paymentMethod.rawValue, notes: t.notes,
                isRecurring: t.isRecurring, source: t.source.rawValue)
        }

        let budgetDTOs = budgets.map { b in
            BudgetDTO(categoryName: b.categoryName, amount: b.amount, spent: b.spent, month: b.month, year: b.year)
        }

        let lendingDTOs = lendings.map { l in
            LendingDTO(personName: l.personName, amount: l.amount, remainingAmount: l.remainingAmount,
                type: l.type.rawValue, reason: l.reason, date: l.date, dueDate: l.dueDate, isSettled: l.isSettled)
        }

        let backup = BackupData(
            version: 1,
            exportDate: .now,
            transactions: transactionDTOs,
            budgets: budgetDTOs,
            lendings: lendingDTOs
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

    @State private var isExporting = false
    @State private var isImporting = false

    var body: some View {
        List {
            Section("Export") {
                Button("Export Backup") { exportData() }
                    .disabled(isExporting || isImporting)
                if isExporting {
                    HStack { ProgressView(); Text("Exporting...").font(.caption) }
                }
                Text("Saves all transactions, budgets, and lendings as JSON")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Restore") {
                Button("Import Backup") { showImportPicker = true }
                    .disabled(isExporting || isImporting)
                if isImporting {
                    HStack { ProgressView(); Text("Restoring...").font(.caption) }
                }
                Text("Restores data from a previously exported backup file")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
        }
        .navigationTitle("Backup & Restore")
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ActivityView(activityItems: [url])
            }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { importData(url: url) }
        }
    }

    private func exportData() {
        isExporting = true
        Task {
            let service = BackupService(context: context)
            do {
                let data = try service.exportBackup()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HHmm"
                let filename = "FinanceLens_Backup_\(formatter.string(from: .now)).json"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: url)
                exportURL = url
                showExportShare = true
            } catch {
                message = "Export failed: \(error.localizedDescription)"
            }
            isExporting = false
        }
    }

    private func importData(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        isImporting = true
        Task {
            defer { url.stopAccessingSecurityScopedResource() }
            let service = BackupService(context: context)
            guard let data = try? Data(contentsOf: url),
                  let count = try? service.importBackup(data: data) else {
                message = "Import failed"
                isImporting = false
                return
            }
            message = "Restored \(count) transactions successfully"
            isImporting = false
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
