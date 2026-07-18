import Foundation

extension AppItem {
    /// Returns a copy with a custom display name applied if one exists in `preferences`.
    /// Centralizes the custom-name logic that was previously duplicated across 4 call sites.
    func applyingCustomName(from preferences: UserPreferences) -> AppItem {
        guard let customName = preferences.customAppNames[bundleIdentifier] else {
            return self
        }
        var modified = self
        modified.name = customName
        return modified
    }
}
