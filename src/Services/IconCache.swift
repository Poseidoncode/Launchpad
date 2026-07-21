import AppKit
import Foundation

actor IconCache {
    static let shared = IconCache()
    
    // Actor isolation serializes all access to NSCache — no additional lock needed.
    private let cache = NSCache<NSString, NSImage>()
    
    /// Densest attached-display scale, cached so hits skip MainActor.
    /// Invalidated when screen parameters change.
    private var cachedScale: CGFloat?
    
    private nonisolated let screenChangeObserver: ScreenChangeObserver
    
    private init() {
        cache.countLimit = 500
        // Cost limit is approximate; actual NSImage memory varies by representation.
        // 100MB covers ~100 large Retina icons; NSCache still evicts under pressure.
        cache.totalCostLimit = 100 * 1024 * 1024
        
        self.screenChangeObserver = ScreenChangeObserver()
        self.screenChangeObserver.handler = { [weak self] in
            Task { await self?.handleScreenChange() }
        }
        self.screenChangeObserver.start()
    }
    
    /// - Parameter desiredSize: Size in **points**. The cached bitmap is created at
    ///   `desiredSize × backingScaleFactor` pixels so Retina displays stay sharp.
    func icon(for path: String, desiredSize: NSSize = NSSize(width: 128, height: 128)) async -> NSImage? {
        let scale = await backingScaleFactor()
        let key = cacheKey(path: path, size: desiredSize, scale: scale)
        
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        
        // NSWorkspace.shared.icon(forFile:) is thread-safe — no MainActor hop needed
        let icon = NSWorkspace.shared.icon(forFile: path)
        guard icon.isValid else { return icon }
        
        // Always rasterize so we don't retain multi-representation workspace icons,
        // and so point size alone never skips a Retina-quality bitmap.
        let resized = await Task.detached(priority: .utility) {
            icon.resized(to: desiredSize, scale: scale) ?? icon
        }.value
        
        let cost = estimateCost(for: resized)
        cache.setObject(resized, forKey: key as NSString, cost: cost)
        return resized
    }
    
    /// Returns the cached scale, fetching from the main actor only on first use
    /// or after a screen-parameter change.
    private func backingScaleFactor() async -> CGFloat {
        if let cachedScale { return cachedScale }
        let scale = await MainActor.run {
            NSImage.preferredBackingScaleFactor()
        }
        cachedScale = scale
        return scale
    }
    
    private func handleScreenChange() {
        cachedScale = nil
        // Scale is part of the cache key; drop entries so the next lookup
        // re-rasterizes for the new densest display.
        cache.removeAllObjects()
    }
    
    /// Size component uses `.rounded()` to match `UserPreferences.iconRasterPointFootprint`.
    private nonisolated func cacheKey(path: String, size: NSSize, scale: CGFloat) -> String {
        "\(path)_\(Int(size.width.rounded()))x\(Int(size.height.rounded()))@\(scale)"
    }
    
    // Prefer actual bitmap byte size; fall back to pixel dimensions (not point size).
    private nonisolated func estimateCost(for image: NSImage) -> Int {
        if let rep = image.representations.first as? NSBitmapImageRep {
            if rep.bytesPerPlane > 0 { return rep.bytesPerPlane }
            return max(1, rep.pixelsWide * rep.pixelsHigh * 4)
        }
        // Assume 2× Retina when no bitmap rep is available
        let scale: CGFloat = 2.0
        return max(1, Int(image.size.width * scale * image.size.height * scale * 4))
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

extension NSImage {
    /// Rasterize into a Retina-aware bitmap.
    /// `targetSize` is in points; `scale` must be captured on the main actor
    /// (via `preferredBackingScaleFactor()`) before calling from a background queue.
    func resized(to targetSize: NSSize, scale: CGFloat) -> NSImage? {
        let pixelW = max(1, Int(ceil(targetSize.width * scale)))
        let pixelH = max(1, Int(ceil(targetSize.height * scale)))
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        // Point size must stay at targetSize so NSImage reports the correct scale
        // (e.g. 128pt with 256px → 2x). Without this, SwiftUI upscales a 1x bitmap.
        rep.size = targetSize
        
        // Use CGContext directly (thread-safe) instead of NSGraphicsContext (process-global).
        // Match NSBitmapImageRep's .deviceRGB so color spaces stay consistent.
        guard let context = CGContext(
            data: rep.bitmapData,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: rep.bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .high
        
        // Ask for a representation that matches the pixel buffer, not the point size.
        // NSWorkspace icons default to a small .size (often 32×32) even when they
        // contain 512/1024px reps — drawing without this yields a soft upscale.
        let source = (self.copy() as? NSImage) ?? self
        let pixelSize = NSSize(width: CGFloat(pixelW), height: CGFloat(pixelH))
        source.size = pixelSize
        var proposedRect = NSRect(origin: .zero, size: pixelSize)
        guard let cgImage = source.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
        
        let image = NSImage(size: targetSize)
        image.addRepresentation(rep)
        return image
    }
    
    /// Prefer the densest attached display so cached icons stay sharp on any screen.
    /// Floors at 2× even on 1× displays: icons are small, and a Retina-quality
    /// bitmap avoids soft upscales when the window moves to a denser screen.
    /// Fall back to 2× when no screen is available (e.g. early launch / headless).
    /// Call from the main actor when reading `NSScreen.screens`.
    static func preferredBackingScaleFactor() -> CGFloat {
        let maxScale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2.0
        return max(maxScale, 2.0)
    }
}

/// Observes display configuration changes so IconCache / AppScanner can drop stale bitmaps.
final class ScreenChangeObserver {
    var handler: (() -> Void)?
    private var token: NSObjectProtocol?
    
    func start() {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handler?()
        }
    }
    
    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
