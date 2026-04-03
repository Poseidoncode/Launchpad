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
    
    // 添加掃描進度追蹤
    private var isScanning = false
    
    private init() {
        // 預設初始化時不立即掃描，而是等待第一次請求
    }
    
    func scanApps(forceRefresh: Bool = false) async -> [AppItem] {
        if !forceRefresh, let lastScan = lastScanTime, 
           Date().timeIntervalSince(lastScan) < cacheValidDuration,
           !cachedApps.isEmpty {
            return cachedApps
        }
        
        // 防止並發掃描
        if isScanning && !forceRefresh {
            // 如果正在掃描且非強制刷新，等待一小段時間後返回快取
            try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000)) // 100ms
            return cachedApps
        }
        
        isScanning = true
        defer { isScanning = false }
        
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        // 優化：批量處理以提高性能
        for path in searchPaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            // 只處理 .app 檔案
            let appURLs = contents.filter { $0.pathExtension == "app" }
            
            // 批量獲取圖示，而不是逐個獲取
            var batchApps: [AppItem] = []
            for url in appURLs {
                if let app = makeAppItem(from: url) {
                    batchApps.append(app)
                }
            }
            
            apps.append(contentsOf: batchApps)
        }
        
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedApps = sorted
        lastScanTime = Date()
        return sorted
    }
    
    private func makeAppItem(from url: URL) -> AppItem? {
        let bundle = Bundle(url: url)
        let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? url.path
        let icon = IconCache.shared.icon(for: url.path)
        
        return AppItem(
            id: AppItem.stableID(bundleIdentifier: bundleID, path: url),
            name: name,
            bundleIdentifier: bundleID,
            path: url,
            icon: icon
        )
    }
}
