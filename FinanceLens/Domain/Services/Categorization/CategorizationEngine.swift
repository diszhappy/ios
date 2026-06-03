import Foundation
import NaturalLanguage
import CoreML

// MARK: - Categorization Result

struct CategorizationResult {
    let category: String
    let confidence: Double
    let method: CategorizationMethod
}

enum CategorizationMethod: String {
    case keyword, merchant, regex, ml, fallback
}

// MARK: - Categorization Engine

final class CategorizationEngine {
    private var keywordRules: [String: [String]] = [:]
    private var merchantRules: [String: String] = [:]
    private var regexRules: [(NSRegularExpression, String)] = []
    private let nlEmbedding = NLEmbedding.wordEmbedding(for: .english)

    init() {
        loadDefaultRules()
    }

    func categorize(merchant: String, description: String = "") -> CategorizationResult {
        // 1. Exact merchant match
        if let category = matchMerchant(merchant) {
            return CategorizationResult(category: category, confidence: 0.95, method: .merchant)
        }

        // 2. Keyword matching
        let text = "\(merchant) \(description)".lowercased()
        if let category = matchKeywords(text) {
            return CategorizationResult(category: category, confidence: 0.85, method: .keyword)
        }

        // 3. Regex patterns
        if let category = matchRegex(text) {
            return CategorizationResult(category: category, confidence: 0.80, method: .regex)
        }

        // 4. NLP-based semantic similarity
        if let category = matchSemantic(merchant) {
            return CategorizationResult(category: category, confidence: 0.70, method: .ml)
        }

        return CategorizationResult(category: "Miscellaneous", confidence: 0.5, method: .fallback)
    }

    // MARK: - Rule Matching

    private func matchMerchant(_ merchant: String) -> String? {
        let normalized = merchant.lowercased().trimmingCharacters(in: .whitespaces)
        return merchantRules[normalized]
    }

    private func matchKeywords(_ text: String) -> String? {
        for (category, keywords) in keywordRules {
            for keyword in keywords {
                if text.contains(keyword) {
                    return category
                }
            }
        }
        return nil
    }

    private func matchRegex(_ text: String) -> String? {
        for (regex, category) in regexRules {
            if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return category
            }
        }
        return nil
    }

    private func matchSemantic(_ merchant: String) -> String? {
        guard let embedding = nlEmbedding else { return nil }

        let categorySeeds: [String: [String]] = [
            "Food": ["restaurant", "food", "dining", "cafe", "pizza", "burger"],
            "Groceries": ["grocery", "supermarket", "vegetables", "fruits"],
            "Fuel": ["petrol", "diesel", "gasoline", "fuel"],
            "Travel": ["flight", "hotel", "taxi", "ride", "travel"],
            "Shopping": ["shopping", "store", "mall", "fashion", "clothing"],
            "Entertainment": ["movie", "music", "game", "streaming"],
            "Medical": ["hospital", "pharmacy", "doctor", "clinic"],
            "Utilities": ["electricity", "water", "internet", "phone"]
        ]

        var bestCategory = ""
        var bestScore: Double = 0

        for (category, seeds) in categorySeeds {
            for seed in seeds {
                let distance = embedding.distance(between: merchant.lowercased(), and: seed)
                let similarity = max(0, 1.0 - distance)
                if similarity > bestScore {
                    bestScore = similarity
                    bestCategory = category
                }
            }
        }

        return bestScore > 0.3 ? bestCategory : nil
    }

    // MARK: - Rule Loading

    private func loadDefaultRules() {
        for (name, _, _, keywords) in Category.defaults {
            keywordRules[name] = keywords
        }

        merchantRules = [
            "swiggy": "Food", "zomato": "Food", "dominos": "Food",
            "bigbasket": "Groceries", "blinkit": "Groceries", "dmart": "Groceries",
            "amazon": "Shopping", "flipkart": "Shopping", "myntra": "Shopping",
            "netflix": "Entertainment", "spotify": "Entertainment", "hotstar": "Entertainment",
            "uber": "Travel", "ola": "Travel", "rapido": "Travel",
            "apollo": "Medical", "pharmeasy": "Medical",
            "zerodha": "Investment", "groww": "Investment",
            "hp petrol": "Fuel", "indian oil": "Fuel", "bpcl": "Fuel"
        ]

        let emiPattern = try? NSRegularExpression(pattern: #"emi|loan|installment"#, options: .caseInsensitive)
        let upiPattern = try? NSRegularExpression(pattern: #"upi[/-]\w+"#, options: .caseInsensitive)
        if let emi = emiPattern { regexRules.append((emi, "EMI")) }
        if let upi = upiPattern { regexRules.append((upi, "Miscellaneous")) }
    }

    func addMerchantRule(merchant: String, category: String) {
        merchantRules[merchant.lowercased()] = category
    }

    func addKeywordRule(keyword: String, category: String) {
        keywordRules[category, default: []].append(keyword.lowercased())
    }
}
