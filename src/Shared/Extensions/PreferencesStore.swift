import Foundation
import OSLog

extension Notification.Name {
    // Kept for backward compatibility — no longer used for inter-store communication.
    // The RootFeature now handles cross-feature state sync directly.
    static let launchpadPreferencesDidChange = Notification.Name("LaunchpadPreferencesDidChange")
    static let launchpadMemoryPressure = Notification.Name("LaunchpadMemoryPressure")
    static let launchpadAppsDidChange = Notification.Name("LaunchpadAppsDidChange")
}

enum PreferencesStore {
    private static let key = "LaunchpadUserPreferences"
    private static let stagingKey = "LaunchpadUserPreferences_staging"
    private static let lock = OSAllocatedUnfairLock()
    
    static func load() -> UserPreferences {
        lock.withLock {
            // Try real key first
            if let data = UserDefaults.standard.data(forKey: key),
               let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                return prefs
            }
            // Fall back to staging key (crash recovery — write-ahead from last save)
            if let data = UserDefaults.standard.data(forKey: stagingKey),
               let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                Logger.preferences.warning("Recovered preferences from staging key")
                UserDefaults.standard.set(data, forKey: key)
                return prefs
            }
            Logger.preferences.warning("Preferences decode failed, using defaults")
            return .default
        }
    }
    
    static func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            Logger.preferences.error("Preferences encode failed")
            return
        }
        lock.withLock {
            // Write-ahead: staging first, then real key.
            // A crash between the two leaves staging intact for recovery on next load.
            UserDefaults.standard.set(data, forKey: stagingKey)
            UserDefaults.standard.set(data, forKey: key)
            // Clean up staging key — real key is now authoritative
            UserDefaults.standard.removeObject(forKey: stagingKey)
        }
    }
}
