import AppKit
import Foundation
import OSLog

private let cacheLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad", category: "icon-cache")

actor IconCache {
    static let shared = IconCache()
    
    // Actor isolation serializes all access to NSCache — no additional lock needed.
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 500
        // #12 FIX: Cost limit is approximate; actual NSImage memory varies by representation.
        // 50MB is more conservative and still ample for ~500 icons.
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    func icon(for path: String, desiredSize: NSSize = NSSize(width: 64, height: 64)) async -> NSImage? {
        let key = "\(path)_\(Int(desiredSize.width))x\(Int(desiredSize.height))"
        
        // Actor isolation protects against data races — no lock needed
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        
        // Hop to main thread for NSWorkspace.icon(forFile:)
        let icon = await MainActor.run { NSWorkspace.shared.icon(forFile: path) }
        guard icon.isValid else { return icon }
        
        if icon.size == desiredSize {
            let cost = estimateCost(for: icon)
            cache.setObject(icon, forKey: key as NSString, cost: cost)
            return icon
        }
        
        let resized = await Task.detached(priority: .utility) {
            icon.resized(to: desiredSize) ?? icon
        }.value
        
        let cost = estimateCost(for: resized)
        cache.setObject(resized, forKey: key as NSString, cost: cost)
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
        cache.removeAllObjects()
    }
}

extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage? {
        guard self.size != targetSize else { return self }
        
        // Render into a fixed bitmap to avoid retaining the original NSImage
        // via a drawingHandler closure (which would hold the full-size image alive)
        let w = max(1, Int(targetSize.width))
        let h = max(1, Int(targetSize.height))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        // Use CGContext directly (thread-safe) instead of NSGraphicsContext (process-global)
        guard let context = CGContext(
            data: rep.bitmapData,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: rep.bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        let image = NSImage(size: targetSize)
        image.addRepresentation(rep)
        return image
    }
}
