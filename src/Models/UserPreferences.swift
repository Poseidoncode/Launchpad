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
    /// Hover scale applied to grid icons; IconCache rasterizes at `iconSize ×` this.
    static let iconHoverScale: Double = 1.10
    
    /// Point size used when rasterizing icons (includes hover headroom).
    static func iconRasterPointSize(_ iconSize: Double) -> Double {
        iconSize * iconHoverScale
    }
    
    /// Integer point footprint used in IconCache keys (`Int(size.rounded())`).
    /// Must stay in sync with `IconCache.cacheKey` so rescan decisions match hits/misses.
    static func iconRasterPointFootprint(_ iconSize: Double) -> Int {
        Int(iconRasterPointSize(iconSize).rounded())
    }
    
    /// True when `newSize` needs a larger bitmap than `oldSize`.
    /// Compares integer point footprints after hover scale so any growth that
    /// would change the IconCache key (and look soft if reused) triggers a rescan.
    static func iconSizeRequiresHigherResolution(from oldSize: Double, to newSize: Double) -> Bool {
        iconRasterPointFootprint(newSize) > iconRasterPointFootprint(oldSize)
    }
    
    private static func clampIconSize(_ value: Double) -> Double {
        min(max(value, iconSizeRange.lowerBound), iconSizeRange.upperBound)
    }
    
    private static func clampColumns(_ value: Int) -> Int {
        min(max(value, columnsRange.lowerBound), columnsRange.upperBound)
    }
    
    // Custom Decodable to validate bounds from UserDefaults.
    // Decodes each field independently with try? so a single corrupted field
    // falls back to its default instead of discarding all preferences.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode each field independently so one malformed value does not discard
        // otherwise valid layout and naming preferences.
        appOrder = (try? container.decode([UUID].self, forKey: .appOrder)) ?? []
        folders = (try? container.decode([Folder].self, forKey: .folders)) ?? []
        showHiddenApps = (try? container.decode(Bool.self, forKey: .showHiddenApps)) ?? false
        iconSize = Self.clampIconSize((try? container.decode(Double.self, forKey: .iconSize)) ?? 60)
        columns = Self.clampColumns((try? container.decode(Int.self, forKey: .columns)) ?? 7)
        customAppNames = (try? container.decode([String: String].self, forKey: .customAppNames)) ?? [:]
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