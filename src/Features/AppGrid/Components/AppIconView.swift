import AppKit
import SwiftUI

/// Displays an embedded scan icon when available and lazily reloads one after
/// memory pressure has released the grid's strong image references.
struct AppIconView: View {
    let app: AppItem
    let size: CGFloat
    let rasterPointSize: CGFloat

    @State private var loadedIcon: NSImage?
    @State private var loadedAppID: UUID?

    private var icon: NSImage? {
        if app.icon != nil { return app.icon }
        guard loadedAppID == app.id else { return nil }
        return loadedIcon
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
        // Key on app identity, not just nil-ness: two different apps without
        // embedded icons share `app.icon == nil`, and reusing the previous
        // app's lazily loaded bitmap would show the wrong icon.
        .task(id: app.id) {
            guard app.icon == nil else {
                loadedIcon = nil
                loadedAppID = nil
                return
            }
            let fetched = await IconCache.shared.icon(
                for: app.path.path,
                desiredSize: NSSize(width: rasterPointSize, height: rasterPointSize)
            )
            guard !Task.isCancelled else { return }
            loadedIcon = fetched
            loadedAppID = app.id
        }
        .accessibilityHidden(true)
    }
}
