import Foundation
import AppKit

actor AppScanner {
    static let shared = AppScanner()
    
    private let searchPaths: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities")
    ]
    
    private var cachedApps: [AppItem] = []
    private var lastScanTime: Date?
    private let cacheValidDuration: TimeInterval = 300
    
    // Tracks whether a scan is in progress to prevent concurrent scans
    private var isScanning = false
    
    private init() {}
    
    func scanApps(showHidden: Bool = false, forceRefresh: Bool = false) async -> [AppItem] {
        if !forceRefresh, let lastScan = lastScanTime, 
           Date().timeIntervalSince(lastScan) < cacheValidDuration,
           !cachedApps.isEmpty {
            return cachedApps
        }
        
        // Prevent concurrent scans
        if isScanning && !forceRefresh {
            try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000)) // 100ms
            return cachedApps
        }
        
        isScanning = true
        defer { isScanning = false }
        
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        for path in searchPaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [.isApplicationKey],
                options: showHidden ? [] : [.skipsHiddenFiles]
            )) ?? []
            
            let appURLs = contents.filter { $0.pathExtension == "app" }
            
            for url in appURLs {
                if let item = await makeAppItem(from: url) {
                    apps.append(item)
                }
            }
        }
        
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // ponytail: deduplicate by bundleIdentifier — same app from multiple paths shows once
        var seenIDs = Set<String>()
        let deduped = sorted.filter { seenIDs.insert($0.bundleIdentifier).inserted }
        cachedApps = deduped
        lastScanTime = Date()
        return deduped
    }
    
    private func makeAppItem(from url: URL) async -> AppItem? {
        let bundle = Bundle(url: url)
        let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? url.path
        let icon = await IconCache.shared.icon(for: url.path)
        
        return AppItem(
            id: AppItem.stableID(bundleIdentifier: bundleID, path: url),
            name: name,
            bundleIdentifier: bundleID,
            path: url,
            icon: icon
        )
    }
}
