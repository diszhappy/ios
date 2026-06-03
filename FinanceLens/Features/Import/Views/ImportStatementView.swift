import SwiftUI
import UniformTypeIdentifiers

struct ImportStatementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var importedTransactions: [ParsedTransaction] = []
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showResults = false

    private let importService = StatementImportService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    ProgressView("Processing statement...")
                } else if showResults {
                    resultView
                } else {
                    importOptionsView
                }
            }
            .padding()
            .navigationTitle("Import Statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileSelection(result) }
            }
            .alert("Import Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private var importOptionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Import Bank Statement")
                .font(.title2.bold())

            Text("Supported formats: PDF, CSV, TXT")
                .foregroundStyle(.secondary)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("\(importedTransactions.count) transactions found")
                .font(.headline)

            Button("Save All") {
                saveTransactions()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        isProcessing = true
        do {
            importedTransactions = try await importService.importFile(url: url)
            showResults = true
        } catch {
            self.error = error.localizedDescription
        }
        isProcessing = false
    }

    private func saveTransactions() {
        for parsed in importedTransactions {
            let source: TransactionSource = .pdfImport
            context.insert(parsed.toTransaction(source: source))
        }
        try? context.save()
    }
}
