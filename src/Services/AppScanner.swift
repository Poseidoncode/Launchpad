import Foundation
import AppKit
import OSLog

actor AppScanner {
    static let shared = AppScanner()
    
    private let searchPaths: [URL] = {
        var paths: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities")
        ]
        // Under App Sandbox, NSHomeDirectory() returns the container directory,
        // not the real user home. Only add ~/Applications when not sandboxed.
        // We detect sandbox by checking if the container directory exists.
        let realHome = FileManager.default.homeDirectoryForCurrentUser
        let userApps = realHome.appendingPathComponent("Applications")
        if FileManager.default.fileExists(atPath: userApps.path) {
            paths.append(userApps)
        }
        return paths
    }()
    
    private var cachedApps: [AppItem] = []
    private var lastScanTime: Date?
    private let cacheValidDuration: TimeInterval = 300
    
    // Continuation-based scan serialization — eliminates the race condition
    private var scanContinuations: [CheckedContinuation<[AppItem], Never>] = []
    private var isScanning = false
    private var currentScanShowHidden: Bool = false
    
    // Retain the memory pressure source via a helper class to avoid
    // nonisolated(unsafe) on the actor (Swift 5.9 compatibility).
    private nonisolated let memoryPressureObserver: MemoryPressureObserver
    
    private init() {
        // Create observer with a closure that captures a weak reference.
        // The closure is not called during init, so weak self is safe here.
        self.memoryPressureObserver = MemoryPressureObserver()
        self.memoryPressureObserver.handler = { [weak self] in
            Task { await self?.handleMemoryPressure() }
        }
        self.memoryPressureObserver.start()
    }
    
    private func handleMemoryPressure() {
        Logger.appScanner.warning("Memory pressure detected — clearing icon cache")
        cachedApps = []
        lastScanTime = nil
        Task { await IconCache.shared.clear() }
    }
    
    func scanApps(showHidden: Bool = false, forceRefresh: Bool = false) async -> [AppItem] {
        if !forceRefresh, let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < cacheValidDuration,
           !cachedApps.isEmpty,
           currentScanShowHidden == showHidden {
            return cachedApps
        }
        
        // If a scan is already in progress, wait for its result.
        // If the showHidden parameter matches, the waiter receives the same result.
        // If it differs, the waiter will re-check the cache after the current scan
        // completes and start a new scan if needed.
        if isScanning {
            let result = await withCheckedContinuation { continuation in
                scanContinuations.append(continuation)
            }
            // After waiting, check if the cached result matches our request.
            // If not, start a fresh scan with the correct parameter.
            if currentScanShowHidden == showHidden {
                return result
            }
            // Fall through to start a new scan with the correct showHidden.
        }
        
        isScanning = true
        currentScanShowHidden = showHidden
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
    
    private nonisolated func performScan(showHidden: Bool) async -> [AppItem] {
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        for path in searchPaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [.isApplicationKey, .isSymbolicLinkKey],
                options: showHidden ? [] : [.skipsHiddenFiles]
            )) ?? []
            
            // Filter to .app bundles and skip symlinks (path traversal hardening)
            let appURLs = contents.filter { url in
                guard url.pathExtension == "app" else { return false }
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
                    return resourceValues.isSymbolicLink == false
                } catch {
                    // Fail-closed: exclude URLs we cannot verify
                    Logger.appScanner.warning("Could not check symlink status for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return false
                }
            }
            
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
    // nonisolated: avoids serializing 8 concurrent tasks on the actor.
    private nonisolated func makeAppItem(from url: URL) async -> AppItem? {
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

// Helper class to retain the DispatchSource without requiring
// nonisolated(unsafe) on the actor — Swift 5.9 compatible.
private final class MemoryPressureObserver {
    var handler: (() -> Void)?
    private var source: DispatchSourceMemoryPressure?
    
    init() {}
    
    func start() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            if event.contains(.warning) || event.contains(.critical) {
                Logger.appScanner.warning("Memory pressure detected — clearing caches")
                self.handler?()
            }
        }
        source.resume()
        self.source = source
    }
}
