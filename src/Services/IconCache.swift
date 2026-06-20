import AppKit
import Foundation

final class IconCache {
    static let shared = IconCache()
    
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func icon(for path: String, desiredSize: NSSize = NSSize(width: 64, height: 64)) async -> NSImage? {
        let key = "\(path)_\(Int(desiredSize.width))x\(Int(desiredSize.height))" as NSString
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // ponytail: hop to main for NSWorkspace, then resize on a utility thread
        let icon = await MainActor.run { NSWorkspace.shared.icon(forFile: path) }
        guard icon.isValid else { return icon }
        
        if icon.size == desiredSize {
            let cost = Int(icon.size.width * icon.size.height * 4)
            cache.setObject(icon, forKey: key, cost: cost)
            return icon
        }
        
        let resized = await Task.detached(priority: .utility) {
            icon.resized(to: desiredSize) ?? icon
        }.value
        
        let cost = Int(resized.size.width * resized.size.height * 4)
        cache.setObject(resized, forKey: key, cost: cost)
        return resized
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

extension NSImage {
    func resized(to size: NSSize) -> NSImage? {
        guard self.size != size else { return self }
        
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }
}