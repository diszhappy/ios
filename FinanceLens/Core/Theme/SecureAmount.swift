import SwiftUI

/// Displays amount or **** based on secure mode setting.
/// Usage: `SecureAmount(value: 1500)` or `SecureAmount(value: 1500, prefix: "+₹")`
struct SecureAmount: View {
    let value: Double
    var prefix: String = "₹"
    var specifier: String = "%.0f"
    @AppStorage("secureMode") private var secureMode = false

    var body: some View {
        if secureMode {
            Text("\(prefix)****")
        } else {
            Text("\(prefix)\(value, specifier: specifier)")
        }
    }
}

/// String extension for use in non-View contexts
extension Double {
    func secureFormatted(prefix: String = "₹", secureMode: Bool) -> String {
        secureMode ? "\(prefix)****" : "\(prefix)\(Int(self))"
    }
}
