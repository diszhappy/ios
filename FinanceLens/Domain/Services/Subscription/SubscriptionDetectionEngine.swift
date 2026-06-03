import Foundation

final class SubscriptionDetectionEngine {

    struct DetectedSubscription {
        let merchant: String
        let averageAmount: Double
        let frequency: SubscriptionFrequency
        let lastDate: Date
        let transactionCount: Int
        let confidence: Double
    }

    func detect(transactions: [Transaction]) -> [DetectedSubscription] {
        // Group by normalized merchant
        var merchantGroups: [String: [Transaction]] = [:]
        for t in transactions where t.transactionType != .credit {
            merchantGroups[t.normalizedMerchant, default: []].append(t)
        }

        var detected: [DetectedSubscription] = []

        for (merchant, txns) in merchantGroups {
            guard txns.count >= 2 else { continue }

            let sorted = txns.sorted { $0.transactionDate < $1.transactionDate }
            guard let frequency = detectFrequency(dates: sorted.map(\.transactionDate)),
                  let confidence = calculateConfidence(transactions: sorted, frequency: frequency),
                  confidence > 0.6 else { continue }

            let avgAmount = sorted.map(\.amount).reduce(0, +) / Double(sorted.count)

            detected.append(DetectedSubscription(
                merchant: merchant,
                averageAmount: avgAmount,
                frequency: frequency,
                lastDate: sorted.last!.transactionDate,
                transactionCount: sorted.count,
                confidence: confidence
            ))
        }

        return detected.sorted { $0.confidence > $1.confidence }
    }

    private func detectFrequency(dates: [Date]) -> SubscriptionFrequency? {
        guard dates.count >= 2 else { return nil }

        let calendar = Calendar.current
        var intervals: [Int] = []

        for i in 1..<dates.count {
            let days = calendar.dateComponents([.day], from: dates[i-1], to: dates[i]).day ?? 0
            intervals.append(days)
        }

        let avgInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)

        switch avgInterval {
        case 5...9: return .weekly
        case 25...35: return .monthly
        case 80...100: return .quarterly
        case 350...380: return .yearly
        default: return nil
        }
    }

    private func calculateConfidence(transactions: [Transaction], frequency: SubscriptionFrequency) -> Double? {
        guard transactions.count >= 2 else { return nil }

        // Amount consistency (low variance = high confidence)
        let amounts = transactions.map(\.amount)
        let avg = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.map { pow($0 - avg, 2) }.reduce(0, +) / Double(amounts.count)
        let amountConsistency = max(0, 1.0 - (sqrt(variance) / avg))

        // Frequency consistency
        let calendar = Calendar.current
        var intervals: [Int] = []
        for i in 1..<transactions.count {
            let days = calendar.dateComponents([.day], from: transactions[i-1].transactionDate, to: transactions[i].transactionDate).day ?? 0
            intervals.append(days)
        }

        let expectedDays: Double = switch frequency {
        case .weekly: 7
        case .monthly: 30
        case .quarterly: 90
        case .yearly: 365
        }

        let avgInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let frequencyConsistency = max(0, 1.0 - abs(avgInterval - expectedDays) / expectedDays)

        // Count bonus (more occurrences = more confident)
        let countBonus = min(1.0, Double(transactions.count) / 6.0)

        return (amountConsistency * 0.4 + frequencyConsistency * 0.4 + countBonus * 0.2)
    }

    func toSubscription(_ detected: DetectedSubscription) -> Subscription {
        Subscription(
            name: detected.merchant,
            merchant: detected.merchant,
            amount: detected.averageAmount,
            frequency: detected.frequency,
            startDate: detected.lastDate
        )
    }
}
