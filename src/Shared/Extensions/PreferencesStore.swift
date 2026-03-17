import Foundation

enum PreferencesStore {
    private static let key = "LaunchpadUserPreferences"
    
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }
    
    static func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}