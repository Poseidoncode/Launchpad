import AppKit
import Foundation
import os

final class IconCache {
    static let shared = IconCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private let lock = OSAllocatedUnfairLock()
    
    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func icon(for path: String, desiredSize: NSSize = NSSize(width: 64, height: 64)) async -> NSImage? {
        let key = "\(path)_\(Int(desiredSize.width))x\(Int(desiredSize.height))"
        
        // ponytail: double-check with lock — concurrent requests for the same key
        // may both generate, but only one result is cached and the extra work is negligible
        if let cached = lock.withLock({ cache.object(forKey: key as NSString) }) {
            return cached
        }
        
        // ponytail: hop to main for NSWorkspace, then resize on a utility thread
        let icon = await MainActor.run { NSWorkspace.shared.icon(forFile: path) }
        guard icon.isValid else { return icon }
        
        if icon.size == desiredSize {
            let cost = Int(icon.size.width * icon.size.height * 4)
            lock.withLock { cache.setObject(icon, forKey: key as NSString, cost: cost) }
            return icon
        }
        
        let resized = await Task.detached(priority: .utility) {
            icon.resized(to: desiredSize) ?? icon
        }.value
        
        let cost = Int(resized.size.width * resized.size.height * 4)
        lock.withLock { cache.setObject(resized, forKey: key as NSString, cost: cost) }
        return resized
    }
    
    func clear() {
        lock.withLock { cache.removeAllObjects() }
    }
}

extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage? {
        guard self.size != targetSize else { return self }
        
        // ponytail: drawing handler instead of deprecated lockFocus API
        return NSImage(size: targetSize, flipped: false) { [self] _ in
            self.draw(in: NSRect(origin: .zero, size: targetSize))
            return true
        }
    }
}