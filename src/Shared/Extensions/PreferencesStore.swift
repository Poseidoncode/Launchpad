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
    
    /// Bundle ID is fixed by build-app.sh. The sandboxed build kept its
    /// UserDefaults plist inside the app container at this path.
    private static let sandboxBundleID = "com.poseidoncode.launchpad"
    private static let migrationFlagKey = "LaunchpadSandboxMigrationAttempted"

    static func load() -> UserPreferences {
        if let prefs = loadLocked() {
            return prefs
        }
        // Both keys missed: first launch, corrupted data, or an upgrade from
        // the sandboxed build (its UserDefaults live in the app container).
        // Migration runs outside the lock — save() locks internally.
        if let migrated = migrateFromSandboxContainer() {
            save(migrated)
            return migrated
        }
        Logger.preferences.warning("Preferences decode failed, using defaults")
        return .default
    }

    private static func loadLocked() -> UserPreferences? {
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
            return nil
        }
    }

    /// One-time import of folder layout / names / settings left behind by the
    /// sandboxed build. Attempted at most once (flagged in the new defaults);
    /// returns nil on first launches and when no container plist exists.
    private static func migrateFromSandboxContainer() -> UserPreferences? {
        guard !UserDefaults.standard.bool(forKey: migrationFlagKey) else { return nil }
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
        let containerPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(sandboxBundleID)/Data/Library/Preferences/\(sandboxBundleID).plist")
        guard let data = try? Data(contentsOf: containerPlist),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let prefsData = plist[key] as? Data,
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: prefsData) else {
            return nil
        }
        Logger.preferences.info("Migrated preferences from sandboxed app container")
        return prefs
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
