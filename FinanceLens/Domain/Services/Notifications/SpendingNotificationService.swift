import Foundation
import UserNotifications
import SwiftData

@MainActor
final class SpendingNotificationService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleDailyNotification(hour: Int, minute: Int) async {
        guard await requestPermission() else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-spending"])

        let content = UNMutableNotificationContent()
        content.title = "Daily Spending Summary"
        content.body = generateDailySummary()
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-spending", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleWeeklyNotification(weekday: Int, hour: Int, minute: Int) async {
        guard await requestPermission() else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-spending"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Finance Report"
        content.body = generateWeeklySummary()
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-spending", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
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

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-spending", "weekly-spending"])
    }
}
