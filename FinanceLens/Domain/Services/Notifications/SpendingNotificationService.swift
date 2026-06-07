import Foundation
import UserNotifications
import SwiftData

@MainActor
final class SpendingNotificationService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleDailyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Spending Summary"
        content.sound = .default

        // Trigger at 9 PM every day
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily-spending", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWeeklyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Finance Report"
        content.sound = .default

        // Trigger every Sunday at 10 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1
        dateComponents.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "weekly-spending", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func generateDailySummary() -> String {
        let repo = TransactionRepository(context: context)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let spent = (try? repo.totalSpending(from: today, to: tomorrow)) ?? 0
        let count = (try? repo.fetchAll(from: today, to: tomorrow).count) ?? 0
        return "You spent ₹\(Int(spent)) today across \(count) transactions."
    }

    func generateWeeklySummary() -> String {
        let repo = TransactionRepository(context: context)
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!

        let spent = (try? repo.totalSpending(from: weekAgo, to: now)) ?? 0
        let income = (try? repo.totalIncome(from: weekAgo, to: now)) ?? 0
        return "This week: ₹\(Int(spent)) spent, ₹\(Int(income)) earned, ₹\(Int(income - spent)) saved."
    }

    func sendImmediateSummary(daily: Bool) {
        let content = UNMutableNotificationContent()
        content.title = daily ? "Today's Spending" : "Weekly Summary"
        content.body = daily ? generateDailySummary() : generateWeeklySummary()
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-spending", "weekly-spending"])
    }
}
