import SwiftUI

extension View {
    /// Classic Launchpad "jiggle" while editing: a small perpetual rotation.
    /// Bound to `active` so it starts when entering edit mode and settles flat
    /// when leaving; a no-op modifier otherwise.
    func jiggling(active: Bool) -> some View {
        rotationEffect(.degrees(active ? 1.4 : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.15),
                value: active
            )
    }

    /// Keyboard-selection ring for arrow-key navigation (Fix 6).
    func keyboardSelected(_ selected: Bool) -> some View {
        overlay {
            if selected {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }
}
