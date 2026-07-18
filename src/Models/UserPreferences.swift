import Foundation

@propertyWrapper
struct Clamped<V: Comparable>: Equatable where V: Equatable {
    let range: ClosedRange<V>
    var wrappedValue: V {
        didSet { wrappedValue = Swift.min(Swift.max(wrappedValue, range.lowerBound), range.upperBound) }
    }
    init(wrappedValue: V, _ range: ClosedRange<V>) {
        self.range = range
        self.wrappedValue = Swift.min(Swift.max(wrappedValue, range.lowerBound), range.upperBound)
    }
    
    static func == (lhs: Clamped<V>, rhs: Clamped<V>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue && lhs.range == rhs.range
    }
}

struct UserPreferences: Equatable, Codable {
    var appOrder: [UUID]
    var folders: [Folder]
    var showHiddenApps: Bool
    @Clamped(16...256) var iconSize: Double = 60
    @Clamped(1...20) var columns: Int = 7
    var customAppNames: [String: String]  // bundleIdentifier -> customName
    
    enum CodingKeys: String, CodingKey {
        case appOrder, folders, showHiddenApps, iconSize, columns, customAppNames
    }
    
    init(
        appOrder: [UUID] = [],
        folders: [Folder] = [],
        showHiddenApps: Bool = false,
        iconSize: Double = 60,
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
    
    // MARK: - Validation
    
    static let iconSizeRange: ClosedRange<Double> = 16...256
    static let columnsRange: ClosedRange<Int> = 1...20
    
    private static func clampIconSize(_ value: Double) -> Double {
        min(max(value, iconSizeRange.lowerBound), iconSizeRange.upperBound)
    }
    
    private static func clampColumns(_ value: Int) -> Int {
        min(max(value, columnsRange.lowerBound), columnsRange.upperBound)
    }
    
    // Custom Decodable to validate bounds from UserDefaults.
    // Uses decodeIfPresent so a single corrupted field falls back to its default
    // instead of discarding all preferences.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appOrder = try container.decodeIfPresent([UUID].self, forKey: .appOrder) ?? []
        folders = try container.decodeIfPresent([Folder].self, forKey: .folders) ?? []
        showHiddenApps = try container.decodeIfPresent(Bool.self, forKey: .showHiddenApps) ?? false
        iconSize = Self.clampIconSize(try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 60)
        columns = Self.clampColumns(try container.decodeIfPresent(Int.self, forKey: .columns) ?? 7)
        customAppNames = try container.decodeIfPresent([String: String].self, forKey: .customAppNames) ?? [:]
    }
    
    // Custom Encodable to handle Clamped property wrappers
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appOrder, forKey: .appOrder)
        try container.encode(folders, forKey: .folders)
        try container.encode(showHiddenApps, forKey: .showHiddenApps)
        try container.encode(iconSize, forKey: .iconSize)
        try container.encode(columns, forKey: .columns)
        try container.encode(customAppNames, forKey: .customAppNames)
    }
}