import Foundation
import AppKit
import OSLog

private let scanLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad", category: "app-scanner")

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
    
    // Continuation-based scan serialization — eliminates the race condition
    private var scanContinuations: [CheckedContinuation<[AppItem], Never>] = []
    private var isScanning = false
    
    // #13: Register for memory pressure to clear caches when needed
    private init() {
        // On macOS, use DispatchSource for memory pressure notifications
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            if event.contains(.warning) || event.contains(.critical) {
                scanLogger.warning("Memory pressure detected — clearing caches")
                Task { await self.handleMemoryPressure() }
            }
        }
        source.resume()
    }
    
    private func handleMemoryPressure() {
        scanLogger.warning("Memory pressure detected — clearing icon cache")
        cachedApps = []
        lastScanTime = nil
        Task { await IconCache.shared.clear() }
    }
    
    func scanApps(showHidden: Bool = false, forceRefresh: Bool = false) async -> [AppItem] {
        if !forceRefresh, let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < cacheValidDuration,
           !cachedApps.isEmpty {
            return cachedApps
        }
        
        // #1 FIX: If a scan is already in progress, wait with cancellation support
        if isScanning {
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    scanContinuations.append(continuation)
                }
            } onCancel: { [self] in
                Task { await self.cancelWaiters() }
            }
        }
        
        isScanning = true
        let apps = await performScan(showHidden: showHidden)
        
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // deduplicate by bundleIdentifier — same app from multiple paths shows once
        var seenIDs = Set<String>()
        let deduped = sorted.filter { seenIDs.insert($0.bundleIdentifier).inserted }
        cachedApps = deduped
        lastScanTime = Date()
        isScanning = false
        
        // Wake all waiters with the same result
        let waiters = scanContinuations
        scanContinuations.removeAll()
        for continuation in waiters {
            continuation.resume(returning: deduped)
        }
        
        return deduped
    }
    
    private func cancelWaiters() {
        let waiters = scanContinuations
        scanContinuations.removeAll()
        for continuation in waiters {
            continuation.resume(returning: [])
        }
    }
    
    private nonisolated func performScan(showHidden: Bool) async -> [AppItem] {
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
            
            // #3 FIX: Bounded concurrency — limit to 8 concurrent tasks instead of unbounded
            let items = await withTaskGroup(of: AppItem?.self, returning: [AppItem].self) { group in
                var results: [AppItem] = []
                var iterator = appURLs.makeIterator()
                let maxConcurrent = 8
                
                // Fill initial batch up to maxConcurrent
                for _ in 0..<maxConcurrent {
                    guard let url = iterator.next() else { break }
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        return await self.makeAppItem(from: url)
                    }
                }
                // As each task completes, start the next one
                while let item = await group.next() {
                    if let item { results.append(item) }
                    if let url = iterator.next() {
                        group.addTask {
                            guard !Task.isCancelled else { return nil }
                            return await self.makeAppItem(from: url)
                        }
                    }
                }
                return results
            }
            apps.append(contentsOf: items)
        }
        
        return apps
    }
    
    // #3 FIX: Removed unnecessary Task.detached — the TaskGroup child task
    // is already off the actor. Bundle(url:) is a fast synchronous plist read.
    private func makeAppItem(from url: URL) async -> AppItem? {
        guard !Task.isCancelled else { return nil }
        
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
