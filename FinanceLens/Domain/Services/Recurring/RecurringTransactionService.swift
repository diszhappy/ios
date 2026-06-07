import Foundation
import SwiftData

@MainActor
final class RecurringTransactionService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Check all detected subscriptions and auto-create transactions that are due
    func processRecurringTransactions() {
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isActive })
        guard let subscriptions = try? context.fetch(descriptor) else { return }

        for subscription in subscriptions {
            guard let nextDue = subscription.nextDueDate, nextDue <= Date() else { continue }

            // Check if transaction already exists for this period
            let merchant = subscription.merchant
            let dueDate = nextDue
            let existingDescriptor = FetchDescriptor<Transaction>()
            let existing = (try? context.fetch(existingDescriptor)) ?? []
            let alreadyAdded = existing.contains {
                $0.normalizedMerchant == merchant &&
                Calendar.current.isDate($0.transactionDate, inSameDayAs: dueDate)
            }

            guard !alreadyAdded else {
                // Advance next due date anyway
                subscription.nextDueDate = subscription.frequency.nextDate(from: nextDue)
                continue
            }

            // Create the recurring transaction
            let transaction = Transaction(
                amount: subscription.amount,
                merchant: subscription.merchant,
                normalizedMerchant: subscription.merchant,
                categoryName: subscription.categoryName,
                transactionDate: nextDue,
                transactionType: .subscription,
                paymentMethod: .card,
                isRecurring: true,
                source: .manual
            )
            context.insert(transaction)

            // Advance to next due date
            subscription.nextDueDate = subscription.frequency.nextDate(from: nextDue)
        }

        try? context.save()
    }
}
