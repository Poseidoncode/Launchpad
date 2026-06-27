import AppKit
import Foundation
import OSLog

private let cacheLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad", category: "icon-cache")

actor IconCache {
    static let shared = IconCache()
    
    // #2 FIX: NSCache is not Sendable. Actor isolation alone doesn't protect against
    // reentrancy during suspension points (MainActor.run). Add explicit lock.
    private let cache = NSCache<NSString, NSImage>()
    private let cacheLock = NSLock()
    
    private init() {
        cache.countLimit = 500
        // #12 FIX: Cost limit is approximate; actual NSImage memory varies by representation.
        // 50MB is more conservative and still ample for ~500 icons.
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    func icon(for path: String, desiredSize: NSSize = NSSize(width: 64, height: 64)) async -> NSImage? {
        let key = "\(path)_\(Int(desiredSize.width))x\(Int(desiredSize.height))"
        
        // #2 FIX: Lock around NSCache access to prevent data races during actor reentrancy
        if let cached = cacheLock.withLock({ cache.object(forKey: key as NSString) }) {
            return cached
        }
        
        // Hop to main thread for NSWorkspace.icon(forFile:)
        let icon = await MainActor.run { NSWorkspace.shared.icon(forFile: path) }
        guard icon.isValid else { return icon }
        
        if icon.size == desiredSize {
            let cost = estimateCost(for: icon)
            cacheLock.withLock { cache.setObject(icon, forKey: key as NSString, cost: cost) }
            return icon
        }
        
        let resized = await Task.detached(priority: .utility) {
            icon.resized(to: desiredSize) ?? icon
        }.value
        
        let cost = estimateCost(for: resized)
        cacheLock.withLock { cache.setObject(resized, forKey: key as NSString, cost: cost) }
        return resized
    }
    
    // #12 FIX: Use actual bitmap representation size when available, fallback to estimate
    private nonisolated func estimateCost(for image: NSImage) -> Int {
        if let rep = image.representations.first as? NSBitmapImageRep {
            return rep.bytesPerPlane > 0 ? rep.bytesPerPlane : Int(image.size.width * image.size.height * 4)
        }
        return Int(image.size.width * image.size.height * 4)
    }
    
    func clear() {
        cacheLock.withLock { cache.removeAllObjects() }
    }
}

extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage? {
        guard self.size != targetSize else { return self }
        
        // Drawing handler instead of deprecated lockFocus API
        return NSImage(size: targetSize, flipped: false) { [self] _ in
            self.draw(in: NSRect(origin: .zero, size: targetSize))
            return true
        }
    }
}
