import Foundation

final class TXTStatementParser: StatementParser {
    private let pdfParser = PDFStatementParser()

    func parse(data: Data) async throws -> [ParsedTransaction] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFile
        }

        // Try CSV-style first (tab or pipe delimited)
        if content.contains("\t") || content.contains("|") {
            let normalized = content
                .replacingOccurrences(of: "\t", with: ",")
                .replacingOccurrences(of: "|", with: ",")
            let csvParser = CSVStatementParser()
            if let data = normalized.data(using: .utf8),
               let results = try? await csvParser.parse(data: data), !results.isEmpty {
                return results
            }
        }

        // Fall back to line-by-line parsing (same logic as PDF text extraction)
        return try await pdfParser.parse(data: data)
    }
}

// MARK: - Import Service

@MainActor
final class StatementImportService {
    private let parsers: [String: StatementParser] = [
        "pdf": PDFStatementParser(),
        "csv": CSVStatementParser(),
        "txt": TXTStatementParser()
    ]

    func importFile(url: URL) async throws -> [ParsedTransaction] {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.invalidFile
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        guard let parser = parsers[ext] else {
            throw ImportError.parsingFailed("Unsupported file type: \(ext)")
        }

        return try await parser.parse(data: data)
    }

    func supportedTypes() -> [String] {
        Array(parsers.keys)
    }
}
