import XCTest
@testable import FinanceLens

final class CategorizationEngineTests: XCTestCase {
    private var engine: CategorizationEngine!

    override func setUp() {
        engine = CategorizationEngine()
    }

    func testMerchantMatch() {
        let result = engine.categorize(merchant: "Swiggy")
        XCTAssertEqual(result.category, "Food")
        XCTAssertEqual(result.method, .merchant)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testKeywordMatch() {
        let result = engine.categorize(merchant: "Unknown Restaurant", description: "food delivery")
        XCTAssertEqual(result.category, "Food")
        XCTAssertEqual(result.method, .keyword)
    }

    func testFallback() {
        let result = engine.categorize(merchant: "XYZABC123")
        XCTAssertEqual(result.category, "Miscellaneous")
        XCTAssertEqual(result.method, .fallback)
    }

    func testCustomRule() {
        engine.addMerchantRule(merchant: "myshop", category: "Shopping")
        let result = engine.categorize(merchant: "myshop")
        XCTAssertEqual(result.category, "Shopping")
    }
}

final class MerchantRecognitionTests: XCTestCase {
    private var engine: MerchantRecognitionEngine!

    override func setUp() {
        engine = MerchantRecognitionEngine()
    }

    func testNormalization() {
        XCTAssertEqual(engine.normalize("AMZN"), "Amazon")
        XCTAssertEqual(engine.normalize("amazon pay"), "Amazon")
        XCTAssertEqual(engine.normalize("SWIGGY INSTAMART"), "Swiggy")
        XCTAssertEqual(engine.normalize("netflix com"), "Netflix")
    }

    func testUnknownMerchant() {
        let result = engine.normalize("random store name")
        XCTAssertEqual(result, "Random Store Name")
    }

    func testCategoryLookup() {
        XCTAssertEqual(engine.categoryForMerchant("Amazon"), "Shopping")
        XCTAssertEqual(engine.categoryForMerchant("Netflix"), "Entertainment")
        XCTAssertNil(engine.categoryForMerchant("Unknown"))
    }
}

final class SubscriptionDetectionTests: XCTestCase {
    private var engine: SubscriptionDetectionEngine!

    override func setUp() {
        engine = SubscriptionDetectionEngine()
    }

    func testDetectsMonthlySubscription() {
        let cal = Calendar.current
        let now = Date()
        var transactions: [Transaction] = []

        for i in 0..<4 {
            let date = cal.date(byAdding: .month, value: -i, to: now)!
            let t = Transaction(amount: 199, merchant: "Netflix", normalizedMerchant: "Netflix", transactionDate: date)
            transactions.append(t)
        }

        let detected = engine.detect(transactions: transactions)
        XCTAssertFalse(detected.isEmpty)
        XCTAssertEqual(detected.first?.merchant, "Netflix")
        XCTAssertEqual(detected.first?.frequency, .monthly)
    }

    func testIgnoresIrregularPayments() {
        let transactions = [
            Transaction(amount: 500, merchant: "Random", normalizedMerchant: "Random", transactionDate: Date()),
            Transaction(amount: 1200, merchant: "Random", normalizedMerchant: "Random", transactionDate: Date().addingTimeInterval(-86400 * 45))
        ]

        let detected = engine.detect(transactions: transactions)
        XCTAssertTrue(detected.isEmpty)
    }
}

final class ForecastingTests: XCTestCase {
    func testMovingAverage() {
        let strategy = MovingAverageForecast(windowSize: 3)
        let result = strategy.predict(historicalValues: [1000, 1200, 1100, 1300, 1250], periodsAhead: 1)
        // Average of last 3: (1100 + 1300 + 1250) / 3 = 1216.67
        XCTAssertEqual(result.predictedValue, 1216.67, accuracy: 1)
    }

    func testLinearRegression() {
        let strategy = LinearRegressionForecast()
        let result = strategy.predict(historicalValues: [100, 200, 300, 400, 500], periodsAhead: 1)
        // Perfect linear trend, next should be ~600
        XCTAssertEqual(result.predictedValue, 600, accuracy: 5)
        XCTAssertGreaterThan(result.confidence, 0.8)
    }

    func testLinearRegressionFlat() {
        let strategy = LinearRegressionForecast()
        let result = strategy.predict(historicalValues: [500, 500, 500, 500], periodsAhead: 1)
        XCTAssertEqual(result.predictedValue, 500, accuracy: 1)
    }
}

final class PINManagerTests: XCTestCase {
    override func tearDown() {
        PINManager.removePin()
    }

    func testSetAndVerify() {
        _ = PINManager.setPin("1234")
        XCTAssertTrue(PINManager.verifyPin("1234"))
        XCTAssertFalse(PINManager.verifyPin("0000"))
    }

    func testHasPin() {
        XCTAssertFalse(PINManager.hasPin())
        _ = PINManager.setPin("5678")
        XCTAssertTrue(PINManager.hasPin())
    }
}

final class QueryInterpreterTests: XCTestCase {
    private var interpreter: FinancialQueryInterpreter!

    override func setUp() {
        interpreter = FinancialQueryInterpreter()
    }

    func testSpendingQuery() {
        let result = interpreter.interpret("How much did I spend on food last month?")
        if case .spending(let category, _, let period) = result {
            XCTAssertEqual(category, "Food")
            XCTAssertNotNil(period)
        } else {
            XCTFail("Expected spending query type")
        }
    }

    func testSubscriptionQuery() {
        let result = interpreter.interpret("What subscriptions do I have?")
        if case .subscription = result {
            // pass
        } else {
            XCTFail("Expected subscription query type")
        }
    }

    func testForecastQuery() {
        let result = interpreter.interpret("Predict next month's spending")
        if case .forecast = result {
            // pass
        } else {
            XCTFail("Expected forecast query type")
        }
    }

    func testHealthScoreQuery() {
        let result = interpreter.interpret("What's my financial health score?")
        if case .healthScore = result {
            // pass
        } else {
            XCTFail("Expected healthScore query type")
        }
    }
}
