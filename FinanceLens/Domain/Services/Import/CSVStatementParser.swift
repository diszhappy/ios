import Foundation

final class CSVStatementParser: StatementParser {
    private let dateFormats = ["dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd MMM yyyy"]

    func parse(data: Data) async throws -> [ParsedTransaction] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFile
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { throw ImportError.noTransactionsFound }

        let header = parseCSVLine(lines[0]).map { $0.lowercased() }
        let columns = detectColumns(header: header)

        var transactions: [ParsedTransaction] = []

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            guard fields.count > max(columns.dateIdx, columns.amountIdx) else { continue }

            guard let date = parseDate(fields[columns.dateIdx]),
                  let amount = parseAmount(fields[columns.amountIdx]) else { continue }

            let description = columns.descIdx < fields.count ? fields[columns.descIdx] : ""
            let balance = columns.balanceIdx.flatMap { $0 < fields.count ? parseAmount(fields[$0]) : nil }

            let type: TransactionType = amount < 0 ? .debit : .credit

            transactions.append(ParsedTransaction(
                date: date, description: description,
                amount: abs(amount), balance: balance, type: type
            ))
        }

        guard !transactions.isEmpty else { throw ImportError.noTransactionsFound }
        return transactions
    }

    private struct ColumnMap {
        var dateIdx: Int = 0
        var descIdx: Int = 1
        var amountIdx: Int = 2
        var balanceIdx: Int? = nil
    }

    private func detectColumns(header: [String]) -> ColumnMap {
        var map = ColumnMap()
        for (i, col) in header.enumerated() {
            if col.contains("date") || col.contains("txn") { map.dateIdx = i }
            else if col.contains("desc") || col.contains("narration") || col.contains("particular") { map.descIdx = i }
            else if col.contains("amount") || col.contains("debit") || col.contains("withdrawal") { map.amountIdx = i }
            else if col.contains("balance") || col.contains("closing") { map.balanceIdx = i }
        }
        return map
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" { inQuotes.toggle() }
            else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private func parseDate(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: str.trimmingCharacters(in: .whitespaces)) { return date }
        }
        return nil
    }

    private func parseAmount(_ str: String) -> Double? {
        let cleaned = str.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Double(cleaned)
    }
}
