import Foundation
import SwiftData

@MainActor
enum SampleDataGenerator {
    static func generateSampleTransactions(context: ModelContext) {
        let cal = Calendar.current
        let now = Date()

        let sampleData: [(String, String, Double, TransactionType, PaymentMethod, Int)] = [
            // (merchant, category, amount, type, payment, daysAgo)
            ("Swiggy", "Food", 450, .debit, .upi, 1),
            ("Salary Credit", "Salary", 85000, .credit, .bankTransfer, 2),
            ("Amazon", "Shopping", 2499, .debit, .card, 3),
            ("Netflix", "Subscription", 199, .debit, .card, 5),
            ("HP Petrol", "Fuel", 2000, .debit, .upi, 6),
            ("BigBasket", "Groceries", 1850, .debit, .upi, 7),
            ("Uber", "Travel", 350, .debit, .upi, 8),
            ("Zomato", "Food", 680, .debit, .upi, 10),
            ("Spotify", "Subscription", 119, .debit, .card, 12),
            ("Electricity Bill", "Utilities", 1200, .debit, .netBanking, 14),
            ("Flipkart", "Shopping", 3999, .debit, .card, 15),
            ("Dominos", "Food", 599, .debit, .upi, 17),
            ("Zerodha", "Investment", 5000, .debit, .bankTransfer, 18),
            ("Apollo Pharmacy", "Medical", 850, .debit, .upi, 20),
            ("Airtel Recharge", "Utilities", 599, .debit, .upi, 22),
            ("Starbucks", "Food", 450, .debit, .card, 24),
            ("DMart", "Groceries", 2200, .debit, .upi, 25),
            ("Ola", "Travel", 280, .debit, .upi, 27),
            ("ChatGPT", "Subscription", 1650, .debit, .card, 28),
            ("Rent", "Rent", 15000, .debit, .bankTransfer, 30),
            // Last month data
            ("Swiggy", "Food", 520, .debit, .upi, 35),
            ("Netflix", "Subscription", 199, .debit, .card, 36),
            ("Salary Credit", "Salary", 85000, .credit, .bankTransfer, 32),
            ("Amazon", "Shopping", 1299, .debit, .card, 38),
            ("HP Petrol", "Fuel", 1800, .debit, .upi, 40),
            ("BigBasket", "Groceries", 1650, .debit, .upi, 42),
            ("Spotify", "Subscription", 119, .debit, .card, 43),
            ("Zomato", "Food", 750, .debit, .upi, 45),
            ("Rent", "Rent", 15000, .debit, .bankTransfer, 60),
            // 2 months ago
            ("Netflix", "Subscription", 199, .debit, .card, 66),
            ("Spotify", "Subscription", 119, .debit, .card, 73),
            ("Salary Credit", "Salary", 82000, .credit, .bankTransfer, 62),
            ("Swiggy", "Food", 380, .debit, .upi, 65),
            ("Amazon", "Shopping", 4500, .debit, .card, 70),
            ("Rent", "Rent", 15000, .debit, .bankTransfer, 90),
        ]

        let merchantEngine = MerchantRecognitionEngine()
        let categorizationEngine = CategorizationEngine()

        for (merchant, category, amount, type, payment, daysAgo) in sampleData {
            let date = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            let normalized = merchantEngine.normalize(merchant)

            let transaction = Transaction(
                amount: amount,
                merchant: merchant,
                normalizedMerchant: normalized,
                categoryName: category,
                transactionDate: date,
                transactionType: type,
                paymentMethod: payment,
                source: .manual
            )
            context.insert(transaction)
        }

        try? context.save()
    }

    static func generateSampleBudgets(context: ModelContext) {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)

        let budgets: [(String, Double)] = [
            ("Food", 5000),
            ("Shopping", 5000),
            ("Fuel", 3000),
            ("Groceries", 4000),
            ("Utilities", 2000),
            ("Entertainment", 1000),
            ("Travel", 2000)
        ]

        for (category, amount) in budgets {
            let budget = Budget(categoryName: category, amount: amount, month: month, year: year)
            context.insert(budget)
        }

        try? context.save()
    }
}
