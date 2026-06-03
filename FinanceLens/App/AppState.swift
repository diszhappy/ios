import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isUnlocked = false
    @Published var isFirstLaunch: Bool

    init() {
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }

    func markLaunched() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        isFirstLaunch = false
    }

    func unlock() {
        isUnlocked = true
    }

    func lock() {
        isUnlocked = false
    }
}
