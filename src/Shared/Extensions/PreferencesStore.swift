import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.launchpad.app", category: "preferences")
private let prefsQueue = DispatchQueue(label: "com.launchpad.preferences")

enum PreferencesStore {
    private static let key = "LaunchpadUserPreferences"
    private static let stagingKey = "LaunchpadUserPreferences_staging"
    
    static func load() -> UserPreferences {
        prefsQueue.sync {
            // Try real key first
            if let data = UserDefaults.standard.data(forKey: key),
               let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                return prefs
            }
            // Fall back to staging key (crash recovery — write-ahead from last save)
            if let data = UserDefaults.standard.data(forKey: stagingKey),
               let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                logger.warning("Recovered preferences from staging key")
                UserDefaults.standard.set(data, forKey: key)
                return prefs
            }
            logger.warning("Preferences decode failed, using defaults")
            return .default
        }
    }
    
    static func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            logger.error("Preferences encode failed")
            return
        }
        prefsQueue.sync {
            // Write-ahead: staging first, then real key.
            // A crash between the two leaves staging intact for recovery on next load.
            UserDefaults.standard.set(data, forKey: stagingKey)
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}