import SwiftUI

struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(isActive ? Color.accentColor : Color.white.opacity(isHovered ? 1.0 : 0.75))
                .frame(width: 28, height: 28)
                .background(isActive ? Color.accentColor.opacity(0.2) : (isHovered ? Color.white.opacity(0.15) : .clear), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
