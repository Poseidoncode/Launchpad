import AppKit
import Foundation

final class IconCache {
    static let shared = IconCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()
    
    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func icon(for path: String, desiredSize: NSSize = NSSize(width: 64, height: 64)) -> NSImage? {
        let key = "\(path)_\(Int(desiredSize.width))x\(Int(desiredSize.height))" as NSString
        
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let icon = NSWorkspace.shared.icon(forFile: path)
        if icon.isValid {
            let resized = icon.resized(to: desiredSize) ?? icon
            let cost = Int(resized.size.width * resized.size.height * 4)
            cache.setObject(resized, forKey: key, cost: cost)
            return resized
        }
        
        return icon
    }
    
    func preload(paths: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for path in paths {
                group.addTask {
                    _ = self.icon(for: path)
                }
            }
        }
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
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