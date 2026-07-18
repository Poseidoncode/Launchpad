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
