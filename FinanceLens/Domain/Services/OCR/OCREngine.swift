import Vision
import UIKit
import Foundation

final class OCREngine {
    struct OCRResult {
        let merchant: String
        let amount: Double?
        let date: Date?
        let referenceNumber: String?
        let rawText: String
    }

    func extractTransactions(from image: UIImage) async throws -> [OCRResult] {
        guard let cgImage = image.cgImage else {
            throw ImportError.invalidFile
        }

        let text = try await recognizeText(in: cgImage)
        return parseOCRText(text)
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-IN", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseOCRText(_ text: String) -> [OCRResult] {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var results: [OCRResult] = []

        let amountPattern = #"₹?\s?[\d,]+\.?\d{0,2}"#
        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#
        let refPattern = #"[A-Z]{2,4}\d{8,20}"#

        let amountRegex = try? NSRegularExpression(pattern: amountPattern)
        let dateRegex = try? NSRegularExpression(pattern: datePattern)
        let refRegex = try? NSRegularExpression(pattern: refPattern)

        // Group lines into transaction blocks
        var currentAmount: Double?
        var currentDate: Date?
        var currentRef: String?
        var currentMerchant: String = ""

        for line in lines {
            // Extract amount
            if let match = amountRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range, in: line) {
                let amountStr = String(line[range])
                    .replacingOccurrences(of: "₹", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let amount = Double(amountStr), amount > 0 {
                    // Save previous block if exists
                    if let prevAmount = currentAmount {
                        results.append(OCRResult(
                            merchant: currentMerchant.isEmpty ? "Unknown" : currentMerchant,
                            amount: prevAmount, date: currentDate,
                            referenceNumber: currentRef, rawText: text
                        ))
                    }
                    currentAmount = amount
                    currentDate = nil
                    currentRef = nil
                    currentMerchant = ""
                }
            }

            // Extract date
            if let match = dateRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range, in: line) {
                currentDate = parseDate(String(line[range]))
            }

            // Extract reference
            if let match = refRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range, in: line) {
                currentRef = String(line[range])
            }

            // Merchant is typically a line without numbers
            let hasNumbers = line.rangeOfCharacter(from: .decimalDigits) != nil
            if !hasNumbers && line.count > 3 && currentMerchant.isEmpty {
                currentMerchant = line.trimmingCharacters(in: .whitespaces)
            }
        }

        // Save last block
        if let amount = currentAmount {
            results.append(OCRResult(
                merchant: currentMerchant.isEmpty ? "Unknown" : currentMerchant,
                amount: amount, date: currentDate,
                referenceNumber: currentRef, rawText: text
            ))
        }

        return results
    }

    private func parseDate(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        for format in ["dd/MM/yyyy", "dd-MM-yyyy", "dd/MM/yy", "MM/dd/yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: str) { return date }
        }
        return nil
    }

    func ocrResultToTransaction(_ result: OCRResult) -> Transaction {
        Transaction(
            amount: result.amount ?? 0,
            merchant: result.merchant,
            transactionDate: result.date ?? .now,
            transactionType: .debit,
            notes: result.referenceNumber ?? "",
            source: .ocr
        )
    }
}
