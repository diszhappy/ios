import SwiftUI
import PDFKit

// MARK: - Report Generator

@MainActor
final class ReportGenerator {
    private let repository: TransactionRepository
    private let budgetRepository: BudgetRepository

    init(repository: TransactionRepository, budgetRepository: BudgetRepository) {
        self.repository = repository
        self.budgetRepository = budgetRepository
    }

    func generateCSV(from startDate: Date, to endDate: Date) throws -> Data {
        let transactions = try repository.fetchAll(from: startDate, to: endDate)
        var csv = "Date,Merchant,Category,Amount,Type,Payment Method,Notes\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for t in transactions {
            let row = [
                formatter.string(from: t.transactionDate),
                t.merchant.replacingOccurrences(of: ",", with: ";"),
                t.categoryName,
                String(format: "%.2f", t.amount),
                t.transactionType.rawValue,
                t.paymentMethod.rawValue,
                t.notes.replacingOccurrences(of: ",", with: ";")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return Data(csv.utf8)
    }

    func generatePDF(from startDate: Date, to endDate: Date) throws -> Data {
        let transactions = try repository.fetchAll(from: startDate, to: endDate)
        let analytics = AnalyticsEngine(repository: repository)
        let spending = try analytics.spendingAnalytics(from: startDate, to: endDate)
        let categories = try analytics.categoryAnalytics(from: startDate, to: endDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        UIGraphicsBeginPDFPage()
        var yPos: CGFloat = margin

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24)]
        "FinanceLens Financial Report".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)
        yPos += 40

        // Period
        let periodAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.gray]
        "\(dateFormatter.string(from: startDate)) – \(dateFormatter.string(from: endDate))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: periodAttrs)
        yPos += 30

        // Summary
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]

        "Summary".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttrs)
        yPos += 25
        "Income: ₹\(Int(spending.totalIncome))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttrs)
        yPos += 18
        "Expenses: ₹\(Int(spending.totalExpense))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttrs)
        yPos += 18
        "Savings: ₹\(Int(spending.savings))".draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttrs)
        yPos += 18
        "Transactions: \(spending.transactionCount)".draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttrs)
        yPos += 30

        // Categories
        "Spending by Category".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttrs)
        yPos += 25
        for cat in categories.prefix(10) {
            "\(cat.category): ₹\(Int(cat.amount)) (\(Int(cat.percentage))%)".draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttrs)
            yPos += 18
            if yPos > pageHeight - margin { UIGraphicsBeginPDFPage(); yPos = margin }
        }
        yPos += 20

        // Transactions
        "Transactions".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttrs)
        yPos += 25
        for t in transactions.prefix(30) {
            let line = "\(dateFormatter.string(from: t.transactionDate)) | \(t.merchant) | ₹\(Int(t.amount))"
            line.draw(at: CGPoint(x: margin, y: yPos), withAttributes: bodyAttrs)
            yPos += 16
            if yPos > pageHeight - margin { UIGraphicsBeginPDFPage(); yPos = margin }
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }
}

// MARK: - Reports View

struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var showShareSheet = false
    @State private var exportedURL: URL?
    @State private var exportFormat: ExportFormat = .pdf

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Period") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }

                Section("Format") {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Generate Report") { generateReport() }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func generateReport() {
        let repo = TransactionRepository(context: context)
        let budgetRepo = BudgetRepository(context: context)
        let generator = ReportGenerator(repository: repo, budgetRepository: budgetRepo)

        do {
            let data: Data
            let filename: String

            switch exportFormat {
            case .pdf:
                data = try generator.generatePDF(from: startDate, to: endDate)
                filename = "FinanceLens_Report.pdf"
            case .csv:
                data = try generator.generateCSV(from: startDate, to: endDate)
                filename = "FinanceLens_Report.csv"
            }

            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url)
            exportedURL = url
            showShareSheet = true
        } catch {
            print("Report generation failed: \(error)")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
