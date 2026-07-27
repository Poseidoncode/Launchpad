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
    /// Icon size (points) used when `cachedApps` icons were rasterized.
    private var lastScanIconSize: Double?
    private let cacheValidDuration: TimeInterval = 300
    
    // Continuation-based scan serialization — eliminates the race condition
    private var scanContinuations: [CheckedContinuation<[AppItem], Never>] = []
    private var isScanning = false
    private var currentScanShowHidden: Bool = false
    /// Icon size of the in-flight / just-completed scan (for waiter compatibility).
    private var currentScanIconSize: Double = 0
    /// Whether the in-flight / just-completed scan was started with `forceRefresh`.
    /// Waiters that also requested forceRefresh can reuse that result instead of looping forever.
    private var currentScanWasForced = false
    
    // Retain observers via helper classes to avoid
    // nonisolated(unsafe) on the actor (Swift 5.9 compatibility).
    private nonisolated let memoryPressureObserver: MemoryPressureObserver
    private nonisolated let screenChangeObserver: ScreenChangeObserver
    
    private init() {
        // Initialise all stored properties first so self is fully initialised
        // before any closure captures it (even weakly).
        self.memoryPressureObserver = MemoryPressureObserver()
        self.screenChangeObserver = ScreenChangeObserver()
        
        self.memoryPressureObserver.handler = { [weak self] in
            Task { await self?.handleMemoryPressure() }
        }
        self.memoryPressureObserver.start()
        
        self.screenChangeObserver.handler = { [weak self] in
            Task { await self?.handleScreenChange() }
        }
        self.screenChangeObserver.start()
    }
    
    private func invalidateScanCache() {
        cachedApps = []
        lastScanTime = nil
        lastScanIconSize = nil
    }
    
    private func handleMemoryPressure() {
        Logger.appScanner.warning("Memory pressure detected — clearing icon cache")
        invalidateScanCache()
        Task { await IconCache.shared.clear() }
    }
    
    /// Drop embedded-icon scan results so the next scan re-rasterizes for the new scale.
    /// IconCache clears itself separately; AppGridView triggers `.reloadApps` for UI.
    private func handleScreenChange() {
        Logger.appScanner.info("Screen parameters changed — invalidating scan cache")
        invalidateScanCache()
    }
    
    /// Cached / in-flight icons are sharp enough when the requested size does not
    /// need a larger raster footprint than what was already scanned.
    private func iconsCover(requestedSize: Double, scannedSize: Double) -> Bool {
        !UserPreferences.iconSizeRequiresHigherResolution(from: scannedSize, to: requestedSize)
    }
    
    /// - Parameter iconSize: Point size from in-memory preferences. Prefer passing this
    ///   over relying on `PreferencesStore.load()` so a debounced disk save cannot
    ///   supply a stale size during an icon-size-driven rescan.
    func scanApps(
        showHidden: Bool = false,
        forceRefresh: Bool = false,
        iconSize: Double? = nil
    ) async -> [AppItem] {
        let resolvedIconSize = iconSize ?? PreferencesStore.load().iconSize
        
        while true {
            if !forceRefresh,
               let lastScan = lastScanTime,
               let lastIconSize = lastScanIconSize,
               Date().timeIntervalSince(lastScan) < cacheValidDuration,
               !cachedApps.isEmpty,
               currentScanShowHidden == showHidden,
               iconsCover(requestedSize: resolvedIconSize, scannedSize: lastIconSize) {
                return cachedApps
            }
            
            // If a scan is already in progress, wait for its result.
            // Reuse it when showHidden matches, icons cover our size, and we
            // either did not request a force refresh or the completed scan was forced.
            if isScanning {
                let result = await withCheckedContinuation { continuation in
                    scanContinuations.append(continuation)
                }
                if currentScanShowHidden == showHidden,
                   iconsCover(requestedSize: resolvedIconSize, scannedSize: currentScanIconSize),
                   (!forceRefresh || currentScanWasForced) {
                    return result
                }
                // Stale relative to our request — loop and try again (another
                // waiter may already have started the scan we need).
                continue
            }
            
            isScanning = true
            currentScanShowHidden = showHidden
            currentScanIconSize = resolvedIconSize
            currentScanWasForced = forceRefresh
            let apps = await performScan(showHidden: showHidden, iconSize: resolvedIconSize)
            
            let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            // deduplicate by bundleIdentifier — same app from multiple paths shows once
            var seenIDs = Set<String>()
            let deduped = sorted.filter { seenIDs.insert($0.bundleIdentifier).inserted }
            cachedApps = deduped
            lastScanTime = Date()
            lastScanIconSize = resolvedIconSize
            isScanning = false
            
            // Wake all waiters with the same result
            let waiters = scanContinuations
            scanContinuations.removeAll()
            for continuation in waiters {
                continuation.resume(returning: deduped)
            }
            
            return deduped
        }
    }
    
    private nonisolated func performScan(showHidden: Bool, iconSize: Double) async -> [AppItem] {
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
                        return await self.makeAppItem(from: url, iconSize: iconSize)
                    }
                }
                // As each task completes, start the next one
                while let item = await group.next() {
                    if let item { results.append(item) }
                    if let url = iterator.next() {
                        group.addTask {
                            guard !Task.isCancelled else { return nil }
                            return await self.makeAppItem(from: url, iconSize: iconSize)
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
    private nonisolated func makeAppItem(from url: URL, iconSize: Double) async -> AppItem? {
        guard !Task.isCancelled else { return nil }
        
        let bundle = Bundle(url: url)
        let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? url.path
        
        // Match the user's icon size (points), with headroom for hover scale.
        // IconCache rasterizes at points × Retina scale so the grid stays sharp.
        let pointSize = UserPreferences.iconRasterPointSize(iconSize)
        let icon = await IconCache.shared.icon(
            for: url.path,
            desiredSize: NSSize(width: pointSize, height: pointSize)
        )
        
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
