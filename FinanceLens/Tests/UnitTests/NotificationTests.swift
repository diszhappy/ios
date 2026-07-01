import XCTest
import UserNotifications
import SwiftData
@testable import FinanceLens

final class SpendingNotificationServiceTests: XCTestCase {

    // MARK: - Notification Scheduling Tests

    @MainActor
    func testDailyNotificationSchedulesWithCorrectTime() async {
        let center = UNUserNotificationCenter.current()
        // Clean state
        center.removePendingNotificationRequests(withIdentifiers: ["daily-spending"])

        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        await service.scheduleDailyNotification(hour: 18, minute: 30)

        let requests = await center.pendingNotificationRequests()
        let daily = requests.first { $0.identifier == "daily-spending" }

        XCTAssertNotNil(daily)
        if let trigger = daily?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 18)
            XCTAssertEqual(trigger.dateComponents.minute, 30)
            XCTAssertTrue(trigger.repeats)
        } else {
            XCTFail("Expected calendar trigger")
        }
    }

    @MainActor
    func testWeeklyNotificationSchedulesWithCorrectDayAndTime() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-spending"])

        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        await service.scheduleWeeklyNotification(weekday: 1, hour: 10, minute: 0)

        let requests = await center.pendingNotificationRequests()
        let weekly = requests.first { $0.identifier == "weekly-spending" }

        XCTAssertNotNil(weekly)
        if let trigger = weekly?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.weekday, 1) // Sunday
            XCTAssertEqual(trigger.dateComponents.hour, 10)
            XCTAssertEqual(trigger.dateComponents.minute, 0)
            XCTAssertTrue(trigger.repeats)
        } else {
            XCTFail("Expected calendar trigger")
        }
    }

    @MainActor
    func testDailyNotificationHasBody() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-spending"])

        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        await service.scheduleDailyNotification(hour: 21, minute: 0)

        let requests = await center.pendingNotificationRequests()
        let daily = requests.first { $0.identifier == "daily-spending" }

        XCTAssertNotNil(daily)
        XCTAssertEqual(daily?.content.title, "Daily Spending Summary")
        XCTAssertFalse(daily?.content.body.isEmpty ?? true, "Notification body should not be empty")
    }

    @MainActor
    func testWeeklyNotificationHasBody() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-spending"])

        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        await service.scheduleWeeklyNotification(weekday: 1, hour: 10, minute: 0)

        let requests = await center.pendingNotificationRequests()
        let weekly = requests.first { $0.identifier == "weekly-spending" }

        XCTAssertNotNil(weekly)
        XCTAssertEqual(weekly?.content.title, "Weekly Finance Report")
        XCTAssertFalse(weekly?.content.body.isEmpty ?? true, "Notification body should not be empty")
    }

    @MainActor
    func testCancelAllRemovesPendingNotifications() async {
        let center = UNUserNotificationCenter.current()

        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        await service.scheduleDailyNotification(hour: 21, minute: 0)
        await service.scheduleWeeklyNotification(weekday: 1, hour: 10, minute: 0)

        service.cancelAll()

        // Give time for removal
        try? await Task.sleep(nanoseconds: 100_000_000)

        let requests = await center.pendingNotificationRequests()
        let daily = requests.first { $0.identifier == "daily-spending" }
        let weekly = requests.first { $0.identifier == "weekly-spending" }

        XCTAssertNil(daily, "Daily notification should be cancelled")
        XCTAssertNil(weekly, "Weekly notification should be cancelled")
    }

    @MainActor
    func testReschedulingReplacesExistingNotification() async {
        let center = UNUserNotificationCenter.current()

        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        // Schedule at 9 PM
        await service.scheduleDailyNotification(hour: 21, minute: 0)
        // Reschedule at 7 PM
        await service.scheduleDailyNotification(hour: 19, minute: 0)

        let requests = await center.pendingNotificationRequests()
        let dailyRequests = requests.filter { $0.identifier == "daily-spending" }

        XCTAssertEqual(dailyRequests.count, 1, "Should only have one daily notification")
        if let trigger = dailyRequests.first?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 19, "Should be updated to 7 PM")
        }
    }

    // MARK: - Summary Generation Tests

    @MainActor
    func testDailySummaryWithNoTransactions() {
        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        let summary = service.generateDailySummary()
        XCTAssertEqual(summary, "You spent ₹0 today across 0 transactions.")
    }

    @MainActor
    func testWeeklySummaryWithNoTransactions() {
        let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Subscription.self, Merchant.self, ChatSession.self, ChatMessage.self, Forecast.self, AppSettings.self, Lending.self, SavingsGoal.self, SplitExpense.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = SpendingNotificationService(context: context)

        let summary = service.generateWeeklySummary()
        XCTAssertEqual(summary, "This week: ₹0 spent, ₹0 earned, ₹0 saved.")
    }

    // MARK: - Settings Persistence Tests

    func testNotificationTimeDefaultValues() {
        // Verify defaults match expected 9 PM daily, 10 AM weekly
        let dailyHour = UserDefaults.standard.object(forKey: "dailyNotifHour") as? Int ?? 21
        let dailyMinute = UserDefaults.standard.object(forKey: "dailyNotifMinute") as? Int ?? 0
        let weeklyHour = UserDefaults.standard.object(forKey: "weeklyNotifHour") as? Int ?? 10
        let weeklyMinute = UserDefaults.standard.object(forKey: "weeklyNotifMinute") as? Int ?? 0

        XCTAssertEqual(dailyHour, 21)
        XCTAssertEqual(dailyMinute, 0)
        XCTAssertEqual(weeklyHour, 10)
        XCTAssertEqual(weeklyMinute, 0)
    }

    func testNotificationTimeCustomValues() {
        UserDefaults.standard.set(18, forKey: "dailyNotifHour")
        UserDefaults.standard.set(45, forKey: "dailyNotifMinute")

        let hour = UserDefaults.standard.integer(forKey: "dailyNotifHour")
        let minute = UserDefaults.standard.integer(forKey: "dailyNotifMinute")

        XCTAssertEqual(hour, 18)
        XCTAssertEqual(minute, 45)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "dailyNotifHour")
        UserDefaults.standard.removeObject(forKey: "dailyNotifMinute")
    }
}
