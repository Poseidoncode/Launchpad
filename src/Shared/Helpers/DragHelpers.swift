import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Extracts a UUID string from an NSSecureCoding drag item.
/// Handles Data, String, and NSString representations.
func draggedIDString(from item: NSSecureCoding?) -> String? {
    if let data = item as? Data {
        return String(data: data, encoding: .utf8)
    }

    if let string = item as? String {
        return string
    }

    if let nsString = item as? NSString {
        return nsString as String
    }

    return nil
}

/// Location-aware drop delegate for grid tiles. Unlike
/// `.onDrop(of:isTargeted:perform:)` this also reports the drop point, so
/// edit-mode drops can distinguish center (merge into a folder) from edges
/// (reorder) — classic Launchpad behavior — without per-item GeometryReaders:
/// tile widths are deterministic (`iconSize + 20`), so the x offset suffices.
struct PayloadDropDelegate: DropDelegate {
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var proposal: DropProposal? = DropProposal(operation: .move)
    var onDrop: (_ location: CGPoint, _ providers: [NSItemProvider]) -> Bool = { _, _ in false }

    func dropEntered(info: DropInfo) { onEnter() }
    func dropExited(info: DropInfo) { onExit() }
    func dropUpdated(info: DropInfo) -> DropProposal? { proposal }
    func performDrop(info: DropInfo) -> Bool {
        onDrop(info.location, info.itemProviders(for: [.text]))
    }
}

/// Drag payloads: app drags carry a bare UUID string; folder-tile drags are
/// prefixed so drop sites can tell them apart from the same `.text` type.
/// Decoding is async-friendly: callers pass the loaded `NSSecureCoding` item.
enum GridDragPayload {
    case app(UUID)
    case folder(UUID)

    static func appProvider(_ id: UUID) -> NSItemProvider {
        NSItemProvider(object: id.uuidString as NSString)
    }

    static func folderProvider(_ id: UUID) -> NSItemProvider {
        NSItemProvider(object: "folder:\(id.uuidString)" as NSString)
    }

    static func decode(_ item: NSSecureCoding?) -> GridDragPayload? {
        guard let string = draggedIDString(from: item) else { return nil }
        if string.hasPrefix("folder:") {
            guard let id = UUID(uuidString: String(string.dropFirst(7))) else { return nil }
            return .folder(id)
        }
        guard let id = UUID(uuidString: string) else { return nil }
        return .app(id)
    }
}

/// NSViewRepresentable that prevents the window from being dragged
/// when clicking inside the folder detail modal.
struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NonDraggableNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}
