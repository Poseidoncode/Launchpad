import Foundation

struct UserPreferences: Equatable, Codable {
    var appOrder: [UUID]
    var folders: [Folder]
    var showHiddenApps: Bool
    var iconSize: Double
    var columns: Int
    var customAppNames: [String: String]  // bundleIdentifier -> customName
    
    init(
        appOrder: [UUID] = [],
        folders: [Folder] = [],
        showHiddenApps: Bool = false,
        iconSize: Double = 72,
        columns: Int = 7,
        customAppNames: [String: String] = [:]
    ) {
        self.appOrder = appOrder
        self.folders = folders
        self.showHiddenApps = showHiddenApps
        self.iconSize = iconSize
        self.columns = columns
        self.customAppNames = customAppNames
    }
    
    static let `default` = UserPreferences()
}