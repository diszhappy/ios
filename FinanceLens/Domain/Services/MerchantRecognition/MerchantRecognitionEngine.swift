import Foundation

final class MerchantRecognitionEngine {
    private var aliasDatabase: [String: String] = [:] // alias -> normalized name
    private var merchantCategories: [String: String] = [:] // normalized -> category

    init() {
        loadDefaultAliases()
    }

    func normalize(_ rawMerchant: String) -> String {
        let cleaned = rawMerchant
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Exact alias match
        if let normalized = aliasDatabase[cleaned] {
            return normalized
        }

        // Partial match - check if any alias is contained in the merchant string
        for (alias, normalized) in aliasDatabase {
            if cleaned.contains(alias) {
                return normalized
            }
        }

        // Return cleaned version with title case
        return rawMerchant.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    func categoryForMerchant(_ normalizedName: String) -> String? {
        merchantCategories[normalizedName]
    }

    func addAlias(_ alias: String, for normalizedName: String) {
        aliasDatabase[alias.lowercased()] = normalizedName
    }

    // MARK: - Default Aliases

    private func loadDefaultAliases() {
        let aliases: [(normalized: String, aliases: [String], category: String)] = [
            ("Amazon", ["amzn", "amazon pay", "amazon india", "amazon marketplace", "amz", "amazon prime"], "Shopping"),
            ("Swiggy", ["swiggy", "swiggy instamart", "swiggy dineout"], "Food"),
            ("Zomato", ["zomato", "zomato gold", "zomato pro"], "Food"),
            ("Netflix", ["netflix", "netflix com"], "Entertainment"),
            ("Spotify", ["spotify", "spotify india", "spotify premium"], "Entertainment"),
            ("Uber", ["uber", "uber india", "uber eats", "uber trip"], "Travel"),
            ("Ola", ["ola", "ola cabs", "ola money"], "Travel"),
            ("Flipkart", ["flipkart", "flipkart internet", "fk"], "Shopping"),
            ("Myntra", ["myntra", "myntra designs"], "Shopping"),
            ("BigBasket", ["bigbasket", "bb daily", "bb instant"], "Groceries"),
            ("Blinkit", ["blinkit", "grofers", "blinkit grocery"], "Groceries"),
            ("Zerodha", ["zerodha", "zerodha broking"], "Investment"),
            ("Groww", ["groww", "groww invest"], "Investment"),
            ("PhonePe", ["phonepe", "phone pe"], "Miscellaneous"),
            ("Google Pay", ["google pay", "gpay", "googlepay"], "Miscellaneous"),
            ("Paytm", ["paytm", "paytm payments", "paytm mall"], "Miscellaneous"),
            ("HDFC Bank", ["hdfc", "hdfc bank", "hdfc ltd"], "Miscellaneous"),
            ("ICICI Bank", ["icici", "icici bank", "icici prudential"], "Miscellaneous"),
            ("SBI", ["sbi", "state bank", "state bank of india"], "Miscellaneous"),
            ("Jio", ["jio", "reliance jio", "jio fiber", "jio recharge"], "Utilities"),
            ("Airtel", ["airtel", "bharti airtel", "airtel payments"], "Utilities"),
            ("DMart", ["dmart", "d mart", "avenue supermarts"], "Groceries"),
            ("Dominos", ["dominos", "dominos pizza", "jubilant foodworks"], "Food"),
            ("McDonald's", ["mcdonalds", "mcd", "mcdonalds india"], "Food"),
            ("Starbucks", ["starbucks", "tata starbucks"], "Food"),
            ("ChatGPT", ["chatgpt", "openai", "open ai"], "Subscription"),
            ("Apple", ["apple", "apple com", "itunes", "app store", "apple one"], "Subscription"),
            ("YouTube", ["youtube", "youtube premium", "youtube music"], "Entertainment"),
            ("Hotstar", ["hotstar", "disney hotstar", "disney plus"], "Entertainment"),
            ("Rapido", ["rapido", "rapido bike"], "Travel"),
            ("IRCTC", ["irctc", "indian railway"], "Travel"),
            ("MakeMyTrip", ["makemytrip", "mmt", "make my trip"], "Travel"),
            ("LIC", ["lic", "life insurance corporation"], "Insurance"),
            ("Petrol", ["hp petrol", "indian oil", "iocl", "bpcl", "bharat petroleum"], "Fuel")
        ]

        for entry in aliases {
            merchantCategories[entry.normalized] = entry.category
            for alias in entry.aliases {
                aliasDatabase[alias] = entry.normalized
            }
        }
    }
}
