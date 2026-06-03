import Foundation
import SwiftData

@Model
final class Forecast {
    @Attribute(.unique) var id: UUID
    var type: ForecastType
    var categoryName: String?
    var predictedAmount: Double
    var confidence: Double
    var periodStart: Date
    var periodEnd: Date
    var createdAt: Date

    init(type: ForecastType, categoryName: String? = nil, predictedAmount: Double,
         confidence: Double, periodStart: Date, periodEnd: Date) {
        self.id = UUID()
        self.type = type
        self.categoryName = categoryName
        self.predictedAmount = predictedAmount
        self.confidence = confidence
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.createdAt = .now
    }
}

enum ForecastType: String, Codable {
    case monthlySpending, categorySpending, savings, subscription
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var currency: String
    var appLockEnabled: Bool
    var biometricEnabled: Bool
    var pinEnabled: Bool
    var pinHash: String?
    var theme: String
    var defaultBudgetAlerts: Bool
    var createdAt: Date

    init() {
        self.id = UUID()
        self.currency = "INR"
        self.appLockEnabled = false
        self.biometricEnabled = false
        self.pinEnabled = false
        self.theme = "system"
        self.defaultBudgetAlerts = true
        self.createdAt = .now
    }
}
