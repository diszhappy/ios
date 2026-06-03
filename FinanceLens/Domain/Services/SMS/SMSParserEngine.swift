import Foundation
import UserNotifications

/// Parses bank SMS messages into transaction data.
/// iOS does NOT allow reading SMS directly. This works via:
/// 1. User copies SMS text and pastes into app (manual mode)
/// 2. Notification Service Extension filters push notifications (future)
/// 3. Shortcuts automation that forwards SMS text to the app (recommended)
///
/// The app provides a "Paste SMS" input where users paste bank messages.
/// It then parses amount, merchant, type (debit/credit), and account info.

struct ParsedSMS: Identifiable, Hashable {
    let id: UUID
    let rawText: String
    let amount: Double?
    let merchant: String?
    let type: TransactionType
    let accountSuffix: String?
    let date: Date
    let referenceNumber: String?
    var isConfirmed: Bool

    static func == (lhs: ParsedSMS, rhs: ParsedSMS) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func toTransaction() -> Transaction? {
        guard let amount else { return nil }
        return Transaction(
            amount: amount,
            merchant: merchant ?? "Unknown",
            transactionDate: date,
            transactionType: type,
            paymentMethod: .upi,
            notes: "SMS: \(rawText.prefix(50))...",
            source: .manual
        )
    }
}

final class SMSParserEngine {
    // Common Indian bank SMS patterns
    private let debitPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?i)debited.*?(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
            #"(?i)(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)\s*(?:has been|was)?\s*debited"#,
            #"(?i)spent\s*(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
            #"(?i)purchase.*?(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
            #"(?i)withdrawn.*?(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
            #"(?i)paid\s*(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private let creditPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?i)credited.*?(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
            #"(?i)(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)\s*(?:has been|was)?\s*credited"#,
            #"(?i)received\s*(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
            #"(?i)refund.*?(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private let accountPattern = try! NSRegularExpression(pattern: #"(?:a/c|ac|acct|account).*?(\d{4})"#, options: .caseInsensitive)
    private let merchantPattern = try! NSRegularExpression(pattern: #"(?:at|to|from|towards|for)\s+([A-Za-z0-9\s&'./-]+?)(?:\s+on|\s+ref|\s+\d|$)"#, options: .caseInsensitive)
    private let refPattern = try! NSRegularExpression(pattern: #"(?:ref|txn|utr|rrn)[:\s#]*([A-Za-z0-9]+)"#, options: .caseInsensitive)

    func parse(_ smsText: String) -> ParsedSMS {
        let type = detectType(smsText)
        let amount = extractAmount(smsText, type: type)
        let merchant = extractMerchant(smsText)
        let account = extractMatch(accountPattern, in: smsText)
        let reference = extractMatch(refPattern, in: smsText)

        return ParsedSMS(
            id: UUID(),
            rawText: smsText,
            amount: amount,
            merchant: merchant,
            type: type,
            accountSuffix: account,
            date: .now,
            referenceNumber: reference,
            isConfirmed: false
        )
    }

    private func detectType(_ text: String) -> TransactionType {
        for regex in creditPatterns {
            if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return .credit
            }
        }
        return .debit
    }

    private func extractAmount(_ text: String, type: TransactionType) -> Double? {
        let patterns = type == .credit ? creditPatterns : debitPatterns
        for regex in patterns {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range]).replacingOccurrences(of: ",", with: "")
                return Double(amountStr)
            }
        }
        // Fallback: find any amount pattern
        let fallback = try? NSRegularExpression(pattern: #"(?:rs\.?|inr|₹)\s?([\d,]+\.?\d*)"#, options: .caseInsensitive)
        if let match = fallback?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: text) {
            return Double(String(text[range]).replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private func extractMerchant(_ text: String) -> String? {
        if let match = merchantPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: text) {
            let raw = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
        return nil
    }

    private func extractMatch(_ regex: NSRegularExpression, in text: String) -> String? {
        if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
}
