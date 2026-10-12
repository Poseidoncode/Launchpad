import Foundation
import AppKit
import OSLog

actor AppScanner {
    static let shared = AppScanner()
    
    /// Resolve search roots for each scan so a newly created ~/Applications directory
    /// is discovered without requiring an app restart.
    private nonisolated func searchPaths() -> [URL] {
        var paths: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true)
        ]
        let userApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: userApps.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            paths.append(userApps)
        }
        return paths
    }
    
    private struct ScanResult {
        let apps: [AppItem]
        let showHidden: Bool
        let iconSize: Double
        let wasForced: Bool
        let iconEpoch: Int
        let completedAt: Date
        let wasCancelled: Bool
    }

    private var cachedScan: ScanResult?
    /// Optional scan operation for deterministic cache/concurrency tests.
    private let scanOverride: ((Bool, Double) async -> [AppItem])?
    /// Densest display scale at the last screen-change check (`nil` = never checked).
    private var lastKnownScale: CGFloat?
    /// Raster epoch: bumped whenever display scale invalidates embedded icons.
    /// A scan that observes a bump mid-flight discards its results instead of
    /// caching bitmaps that predate the invalidation (see `scanApps`).
    /// Memory-pressure invalidation deliberately does NOT bump this: its
    /// in-flight bitmaps are still correct, only memory-hungry.
    private var iconEpoch = 0
    private let cacheValidDuration: TimeInterval = 300
    
    // Continuations serialize incompatible scans while allowing compatible callers
    // to reuse the exact result that woke them, without consulting mutable metadata.
    private var scanContinuations: [CheckedContinuation<ScanResult, Never>] = []
    private var isScanning = false
    
    // Retain observers via helper classes to avoid
    // nonisolated(unsafe) on the actor (Swift 5.9 compatibility).
    private nonisolated let memoryPressureObserver: MemoryPressureObserver
    private nonisolated let screenChangeObserver: ScreenChangeObserver
    private nonisolated let appDirectoryObserver: AppDirectoryObserver
    
    init(
        scanOverride: ((Bool, Double) async -> [AppItem])? = nil,
        startObservers: Bool = true
    ) {
        self.scanOverride = scanOverride
        // Initialise all stored properties first so self is fully initialised
        // before any closure captures it (even weakly).
        self.memoryPressureObserver = MemoryPressureObserver()
        self.screenChangeObserver = ScreenChangeObserver()
        self.appDirectoryObserver = AppDirectoryObserver()

        self.memoryPressureObserver.handler = { [weak self] in
            Task { await self?.handleMemoryPressure() }
        }
        self.screenChangeObserver.handler = { [weak self] in
            Task { await self?.handleScreenChange() }
        }
        self.appDirectoryObserver.handler = { [weak self] in
            Task { await self?.handleAppDirectoryChange() }
        }
        if startObservers {
            self.memoryPressureObserver.start()
            self.screenChangeObserver.start()
            self.appDirectoryObserver.start(watching: searchPaths())
        }
    }
    
    private func invalidateScanCache() {
        cachedScan = nil
    }
    
    /// An install / uninstall / update touched an app directory. Drop the cache
    /// and tell the UI to rescan silently; the rescan itself is debounced at the
    /// observer so install bursts ( dozens of writes) cause a single refresh.
    private func handleAppDirectoryChange() async {
        Logger.appScanner.info("App directory changed — invalidating scan cache")
        invalidateScanCache()
        await MainActor.run {
            NotificationCenter.default.post(name: .launchpadAppsDidChange, object: nil)
        }
    }

    private func handleMemoryPressure() async {
        Logger.appScanner.warning("Memory pressure detected — clearing icon cache")
        invalidateScanCache()
        await IconCache.shared.clear()
        await MainActor.run {
            NotificationCenter.default.post(name: .launchpadMemoryPressure, object: nil)
        }
    }
    
    /// Drop embedded-icon scan results so the next scan re-rasterizes for the new scale.
    /// Only invalidates when the densest scale actually changed; the notification
    /// also fires for arrangement/colour changes needing no work. IconCache guards
    /// itself separately; AppGridView triggers `.refreshIconsAfterScreenChange`.
    private func handleScreenChange() async {
        let newScale = await MainActor.run {
            NSImage.preferredBackingScaleFactor()
        }
        // Update IconCache before any caller can reuse icons at the old scale.
        await IconCache.shared.updateBackingScale(to: newScale)
        if let lastKnownScale, lastKnownScale == newScale { return }
        lastKnownScale = newScale
        Logger.appScanner.info("Screen parameters changed — invalidating scan cache")
        invalidateScanCache()
        iconEpoch += 1
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

        // Notifications are delivered asynchronously. Check the scale before a
        // cache hit so a screen-change refresh cannot race the notification task.
        await handleScreenChange()
        
        while true {
            if !forceRefresh,
               let cachedScan,
               cachedScan.iconEpoch == iconEpoch,
               Date().timeIntervalSince(cachedScan.completedAt) < cacheValidDuration,
               cachedScan.showHidden == showHidden,
               iconsCover(requestedSize: resolvedIconSize, scannedSize: cachedScan.iconSize) {
                return cachedScan.apps
            }
            
            // Wait for the active scan, then validate its immutable metadata.
            // If it does not satisfy this request, loop and start/join a suitable scan.
            if isScanning {
                let result = await withCheckedContinuation { continuation in
                    scanContinuations.append(continuation)
                }
                if !result.wasCancelled,
                   result.iconEpoch == iconEpoch,
                   result.showHidden == showHidden,
                   iconsCover(requestedSize: resolvedIconSize, scannedSize: result.iconSize),
                   (!forceRefresh || result.wasForced) {
                    return result.apps
                }
                continue
            }
            
            isScanning = true
            let epoch = iconEpoch
            let apps: [AppItem]
            if let scanOverride {
                apps = await scanOverride(showHidden, resolvedIconSize)
            } else {
                apps = await performScan(showHidden: showHidden, iconSize: resolvedIconSize)
            }
            
            if Task.isCancelled {
                isScanning = false
                let cancelledResult = ScanResult(
                    apps: [],
                    showHidden: showHidden,
                    iconSize: resolvedIconSize,
                    wasForced: forceRefresh,
                    iconEpoch: epoch,
                    completedAt: Date(),
                    wasCancelled: true
                )
                let waiters = scanContinuations
                scanContinuations.removeAll()
                for continuation in waiters {
                    continuation.resume(returning: cancelledResult)
                }
                return []
            }

            if epoch != iconEpoch {
                // Invalidation during the scan means its embedded bitmaps are stale.
                isScanning = false
                let staleResult = ScanResult(
                    apps: [],
                    showHidden: showHidden,
                    iconSize: resolvedIconSize,
                    wasForced: forceRefresh,
                    iconEpoch: epoch,
                    completedAt: Date(),
                    wasCancelled: false
                )
                let waiters = scanContinuations
                scanContinuations.removeAll()
                for continuation in waiters {
                    continuation.resume(returning: staleResult)
                }
                continue
            }
            
            let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            // Deduplicate by bundle identifier — same app from multiple paths shows once.
            var seenIDs = Set<String>()
            let deduped = sorted.filter { seenIDs.insert($0.bundleIdentifier).inserted }
            let result = ScanResult(
                apps: deduped,
                showHidden: showHidden,
                iconSize: resolvedIconSize,
                wasForced: forceRefresh,
                iconEpoch: epoch,
                completedAt: Date(),
                wasCancelled: false
            )
            cachedScan = result
            isScanning = false
            
            // Wake all waiters with the exact result and request metadata.
            let waiters = scanContinuations
            scanContinuations.removeAll()
            for continuation in waiters {
                continuation.resume(returning: result)
            }
            
            return deduped
        }
    }
    
    private nonisolated func performScan(showHidden: Bool, iconSize: Double) async -> [AppItem] {
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        for path in searchPaths() {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            
            // Only prefetch the symlink flag we actually read below (cached on the
            // URL, so the per-app check below hits the cache instead of disk).
            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [.isSymbolicLinkKey],
                    options: showHidden ? [] : [.skipsHiddenFiles]
                )
            } catch {
                Logger.appScanner.warning(
                    "Could not enumerate app directory \(path.path, privacy: .private): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }
            
            // Filter to .app bundles and skip symlinks (path traversal hardening)
            let appURLs = contents.filter { url in
                guard url.pathExtension == "app" else { return false }
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
                    return resourceValues.isSymbolicLink == false
                } catch {
                    // Fail-closed: exclude URLs we cannot verify
                    Logger.appScanner.warning("Could not check symlink status for \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
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
        let info = bundle?.infoDictionary
        let name = info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? url.path
        // Mac App Store installs carry a store receipt; classic Launchpad only
        // offered deletion for these. A single stat per app keeps this cheap.
        let isAppStoreApp = FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt", isDirectory: false).path
        )
        
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
            icon: icon,
            isAppStoreApp: isAppStoreApp
        )
    }
}

/// Watches the app search directories for installs / uninstalls / updates so
/// newly installed apps appear without a manual refresh (classic Launchpad
/// behavior). Uses one O_EVTONLY fd + DispatchSource per directory and debounces
/// bursts, since a single install produces many filesystem events.
///
/// Resolves directories once at start; a `~/Applications` created later is still
/// picked up by each scan's dynamic path resolution (just not watched until
/// the next launch).
private final class AppDirectoryObserver {
    var handler: (() -> Void)?
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounce: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.poseidoncode.launchpad.appdir-observer")

    init() {}

    func start(watching directories: [URL]) {
        stop()
        for directory in directories {
            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .rename, .delete, .revoke],
                queue: queue
            )
            source.setEventHandler { [weak self] in self?.schedule() }
            // Balance the open(2): each source owns its fd.
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    private func schedule() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.handler?() }
        debounce = work
        // Installs write many files; settle before rescanning once.
        queue.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func stop() {
        debounce?.cancel()
        debounce = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    deinit { stop() }
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
