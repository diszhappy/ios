import Foundation

// MARK: - Forecasting Protocol

protocol ForecastingStrategy {
    func predict(historicalValues: [Double], periodsAhead: Int) -> ForecastResult
}

struct ForecastResult {
    let predictedValue: Double
    let confidence: Double
    let method: String
}

// MARK: - Moving Average

final class MovingAverageForecast: ForecastingStrategy {
    private let windowSize: Int

    init(windowSize: Int = 3) {
        self.windowSize = windowSize
    }

    func predict(historicalValues: [Double], periodsAhead: Int) -> ForecastResult {
        guard historicalValues.count >= windowSize else {
            let avg = historicalValues.isEmpty ? 0 : historicalValues.reduce(0, +) / Double(historicalValues.count)
            return ForecastResult(predictedValue: avg, confidence: 0.3, method: "Simple Average")
        }

        let window = Array(historicalValues.suffix(windowSize))
        let prediction = window.reduce(0, +) / Double(windowSize)
        let confidence = min(0.85, 0.5 + Double(historicalValues.count) * 0.05)

        return ForecastResult(predictedValue: prediction, confidence: confidence, method: "Moving Average (\(windowSize))")
    }
}

// MARK: - Linear Regression

final class LinearRegressionForecast: ForecastingStrategy {
    func predict(historicalValues: [Double], periodsAhead: Int) -> ForecastResult {
        guard historicalValues.count >= 3 else {
            return MovingAverageForecast().predict(historicalValues: historicalValues, periodsAhead: periodsAhead)
        }

        let n = Double(historicalValues.count)
        let xs = (0..<historicalValues.count).map { Double($0) }
        let ys = historicalValues

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map(*).reduce(0, +)
        let sumX2 = xs.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else {
            return ForecastResult(predictedValue: sumY / n, confidence: 0.3, method: "Flat")
        }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        let futureX = Double(historicalValues.count - 1 + periodsAhead)
        let prediction = max(0, slope * futureX + intercept)

        // R-squared for confidence
        let yMean = sumY / n
        let ssRes = zip(xs, ys).map { slope * $0 + intercept - $1 }.map { $0 * $0 }.reduce(0, +)
        let ssTot = ys.map { $0 - yMean }.map { $0 * $0 }.reduce(0, +)
        let rSquared = ssTot > 0 ? max(0, 1 - ssRes / ssTot) : 0

        return ForecastResult(predictedValue: prediction, confidence: rSquared * 0.9, method: "Linear Regression")
    }
}

// MARK: - Forecasting Engine

@MainActor
final class ForecastingEngine {
    private let repository: TransactionRepository
    private let strategies: [ForecastingStrategy]

    init(repository: TransactionRepository) {
        self.repository = repository
        self.strategies = [LinearRegressionForecast(), MovingAverageForecast()]
    }

    func forecastMonthlySpending(monthsAhead: Int = 1) throws -> ForecastResult {
        let monthlyTotals = try getMonthlyTotals(months: 6)
        return bestPrediction(values: monthlyTotals, periodsAhead: monthsAhead)
    }

    func forecastCategorySpending(category: String, monthsAhead: Int = 1) throws -> ForecastResult {
        let totals = try getMonthlyCategoryTotals(category: category, months: 6)
        return bestPrediction(values: totals, periodsAhead: monthsAhead)
    }

    func forecastEndOfMonth() throws -> ForecastResult {
        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let daysInMonth = cal.range(of: .day, in: .month, for: now)!.count
        let dayOfMonth = cal.component(.day, from: now)

        let spentSoFar = try repository.totalSpending(from: startOfMonth, to: now)
        let dailyRate = dayOfMonth > 0 ? spentSoFar / Double(dayOfMonth) : 0
        let projected = dailyRate * Double(daysInMonth)

        let confidence = Double(dayOfMonth) / Double(daysInMonth)

        return ForecastResult(predictedValue: projected, confidence: confidence, method: "Daily Rate Projection")
    }

    func forecastSavings(monthsAhead: Int = 1) throws -> ForecastResult {
        let cal = Calendar.current
        let now = Date()
        var monthlySavings: [Double] = []

        for i in 1...6 {
            let start = cal.date(byAdding: .month, value: -i, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            let income = try repository.totalIncome(from: start, to: end)
            let expense = try repository.totalSpending(from: start, to: end)
            monthlySavings.append(income - expense)
        }

        return bestPrediction(values: monthlySavings.reversed(), periodsAhead: monthsAhead)
    }

    // MARK: - Helpers

    private func getMonthlyTotals(months: Int) throws -> [Double] {
        let cal = Calendar.current
        let now = Date()
        var totals: [Double] = []

        for i in (1...months).reversed() {
            let start = cal.date(byAdding: .month, value: -i, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            totals.append(try repository.totalSpending(from: start, to: end))
        }
        return totals
    }

    private func getMonthlyCategoryTotals(category: String, months: Int) throws -> [Double] {
        let cal = Calendar.current
        let now = Date()
        var totals: [Double] = []

        for i in (1...months).reversed() {
            let start = cal.date(byAdding: .month, value: -i, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            let spending = try repository.spendingByCategory(from: start, to: end)
            totals.append(spending[category] ?? 0)
        }
        return totals
    }

    private func bestPrediction(values: [Double], periodsAhead: Int) -> ForecastResult {
        let results = strategies.map { $0.predict(historicalValues: values, periodsAhead: periodsAhead) }
        return results.max(by: { $0.confidence < $1.confidence }) ?? results[0]
    }
}
