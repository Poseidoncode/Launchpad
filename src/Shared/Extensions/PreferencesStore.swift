import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.launchpad.app", category: "preferences")
private let prefsQueue = DispatchQueue(label: "com.launchpad.preferences")

enum PreferencesStore {
    private static let key = "LaunchpadUserPreferences"
    
    static func load() -> UserPreferences {
        prefsQueue.sync {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
                logger.warning("Preferences decode failed, using defaults")
                return .default
            }
            return prefs
        }
    }
    
    static func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            logger.error("Preferences encode failed")
            return
        }
        prefsQueue.sync {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}