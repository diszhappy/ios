import Foundation
import PDFKit

// MARK: - Parser Protocol

protocol StatementParser {
    func parse(data: Data) async throws -> [ParsedTransaction]
}

struct ParsedTransaction {
    let date: Date
    let description: String
    let amount: Double
    let balance: Double?
    let type: TransactionType

    func toTransaction(source: TransactionSource) -> Transaction {
        Transaction(
            amount: abs(amount),
            merchant: description,
            transactionDate: date,
            transactionType: type,
            source: source,
            balanceAfter: balance
        )
    }
}

enum ImportError: Error, LocalizedError {
    case invalidFile
    case parsingFailed(String)
    case noTransactionsFound

    var errorDescription: String? {
        switch self {
        case .invalidFile: return "Invalid file format"
        case .parsingFailed(let msg): return "Parsing failed: \(msg)"
        case .noTransactionsFound: return "No transactions found in file"
        }
    }
}

// MARK: - PDF Parser

final class PDFStatementParser: StatementParser {
    private let dateFormats = ["dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd", "dd MMM yyyy", "MM/dd/yyyy"]

    func parse(data: Data) async throws -> [ParsedTransaction] {
        guard let document = PDFDocument(data: data) else {
            throw ImportError.invalidFile
        }

        var allText = ""
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            allText += (page.string ?? "") + "\n"
        }

        let lines = allText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var transactions: [ParsedTransaction] = []

        for line in lines {
            if let parsed = parseLine(line) {
                transactions.append(parsed)
            }
        }

        guard !transactions.isEmpty else { throw ImportError.noTransactionsFound }
        return transactions
    }

    private func parseLine(_ line: String) -> ParsedTransaction? {
        // Pattern: Date ... Description ... Amount (optional Balance)
        let amountPattern = #"[\d,]+\.\d{2}"#
        guard let amountRegex = try? NSRegularExpression(pattern: amountPattern) else { return nil }

        let matches = amountRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        guard !matches.isEmpty else { return nil }

        // Try to extract date from beginning of line
        guard let date = extractDate(from: line) else { return nil }

        // Extract amounts
        let amounts: [Double] = matches.compactMap { match in
            guard let range = Range(match.range, in: line) else { return nil }
            let str = line[range].replacingOccurrences(of: ",", with: "")
            return Double(str)
        }

        guard let amount = amounts.first else { return nil }

        // Extract description (text between date and amount)
        let description = extractDescription(from: line)

        let type: TransactionType = line.lowercased().contains("cr") || amounts.count > 1 ? .credit : .debit
        let balance = amounts.count > 1 ? amounts.last : nil

        return ParsedTransaction(date: date, description: description, amount: amount, balance: balance, type: type)
    }

    private func extractDate(from line: String) -> Date? {
        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#
        guard let regex = try? NSRegularExpression(pattern: datePattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range, in: line) else { return nil }

        let dateStr = String(line[range])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")

        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) { return date }
        }
        return nil
    }

    private func extractDescription(from line: String) -> String {
        // Remove date and amounts, keep middle text
        var desc = line
        // Remove date pattern
        if let regex = try? NSRegularExpression(pattern: #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#) {
            desc = regex.stringByReplacingMatches(in: desc, range: NSRange(desc.startIndex..., in: desc), withTemplate: "")
        }
        // Remove amount patterns
        if let regex = try? NSRegularExpression(pattern: #"[\d,]+\.\d{2}"#) {
            desc = regex.stringByReplacingMatches(in: desc, range: NSRange(desc.startIndex..., in: desc), withTemplate: "")
        }
        return desc.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
