import OSLog

extension Logger {
    static let appGrid = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad",
        category: "app-grid"
    )
    static let appScanner = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad",
        category: "app-scanner"
    )
    static let iconCache = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad",
        category: "icon-cache"
    )
    static let preferences = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad",
        category: "preferences"
    )
}
