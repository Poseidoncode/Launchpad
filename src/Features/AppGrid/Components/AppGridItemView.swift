import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers

struct AppGridItem: View {
    let app: AppItem
    let isEditMode: Bool
    let hasActiveDrag: Bool
    let store: StoreOf<AppGridFeature>
    var onDragStart: () -> Void
    var onDragEnd: () -> Void

    @State private var isHovered = false
    @State private var showRenameSheet = false
    @State private var newName = ""
    @State private var isDraggingLocal = false
    @State private var isCurrentDropTarget = false
    @State private var showTrashConfirmation = false
    private var iconSize: CGFloat { store.preferences.iconSize }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Drop target indicator
                if isCurrentDropTarget && hasActiveDrag {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: iconSize + 6, height: iconSize + 6)
                }

                AppIconView(
                    app: app,
                    size: iconSize,
                    rasterPointSize: CGFloat(UserPreferences.iconRasterPointSize(Double(iconSize)))
                )
                .shadow(color: .black.opacity(0.35), radius: isHovered ? 10 : 4, y: isHovered ? 5 : 2)
                .scaleEffect(isHovered ? CGFloat(UserPreferences.iconHoverScale) : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
                .opacity(isDraggingLocal ? 0.4 : 1.0)
                .jiggling(active: isEditMode)

                // Edit-mode delete badge — App Store apps only, matching classic
                // Launchpad (which never offered deletion for other apps). All
                // apps keep "Move to Trash" in the context menu.
                if isEditMode && app.isAppStoreApp {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showTrashConfirmation = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.system(size: 16))
                                    .background(Circle().fill(.white))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Move \(app.name) to Trash")
                        }
                        Spacer()
                    }
                    .frame(width: iconSize, height: iconSize)
                }
            }
            .keyboardSelected(store.keyboardSelectedID == app.id)

            Text(app.name)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 12)
        }
        .frame(width: iconSize + 20)
        .contentShape(Rectangle())
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Click to launch")
        .onHover { isHovered = $0 }
        .onTapGesture {
            if !isEditMode {
                store.send(.launchApp(app))
            }
        }
        // Classic edit-mode entry: long-press an icon (toolbar toggle kept
        // as a discoverable alternative).
        .onLongPressGesture(minimumDuration: 0.6) {
            if !isEditMode {
                store.send(.setEditMode(true))
            }
        }
        .contextMenu {
            Button("Open") { store.send(.launchApp(app)) }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(app.path.path, inFileViewerRootedAtPath: "")
            }
            Divider()
            Button("Rename") {
                newName = app.name
                showRenameSheet = true
            }
            Divider()
            Button("Move to Trash") {
                showTrashConfirmation = true
            }
        }
        // Drag support - using onDrag for macOS
        .onDrag {
            onDragStart()
            isDraggingLocal = true
            return NSItemProvider(object: app.id.uuidString as NSString)
        } preview: {
            VStack(spacing: 4) {
                AppIconView(
                    app: app,
                    size: 48,
                    rasterPointSize: CGFloat(UserPreferences.iconRasterPointSize(Double(iconSize)))
                )
                Text(app.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        // Drop support — location-aware (Fix 2/8): normal-mode drops are
        // deliberately ignored (classic behavior; prevents accidental reorders),
        // edit-mode center drops merge into a folder, edge drops reorder.
        // Folder tiles can't be dropped onto apps; they are declined below.
        .onDrop(of: [.text], delegate: PayloadDropDelegate(
            onEnter: { isCurrentDropTarget = true },
            onExit: { isCurrentDropTarget = false },
            proposal: isEditMode ? DropProposal(operation: .move) : nil,
            onDrop: { location, providers in
                handleDrop(at: location, providers: providers)
            }
        ))
        .onChange(of: hasActiveDrag) { _, isActive in
            if !isActive {
                isDraggingLocal = false
            }
        }
        .onChange(of: isCurrentDropTarget) { _, newValue in
            // Reset drag state when drop target changes away
            if !newValue && !hasActiveDrag {
                isDraggingLocal = false
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            VStack(spacing: 16) {
                Text("Rename App")
                    .font(.headline)

                TextField("App Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                HStack {
                    Button("Cancel") {
                        showRenameSheet = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.send(.renameApp(bundleIdentifier: app.bundleIdentifier, newName: newName))
                        }
                        showRenameSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 280)
        }
        .confirmationDialog(
            "Move \"\(app.name)\" to the Trash?",
            isPresented: $showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                store.send(.trashApp(app))
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func resetDragState() {
        onDragEnd()
        isDraggingLocal = false
        isCurrentDropTarget = false
    }

    private func handleDrop(at location: CGPoint, providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            resetDragState()
            return false
        }
        // Tile width is deterministic (frame below), so the x offset alone
        // disambiguates edge (reorder) from center (folder) — no GeometryReader.
        let x = location.x
        let width = iconSize + 20
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                defer { resetDragState() }
                guard isEditMode,
                      case let .app(draggedID) = GridDragPayload.decode(item),
                      draggedID != app.id else { return }
                if x < width * 0.25 {
                    store.send(.moveAppBefore(id: draggedID, before: app.id))
                } else if x > width * 0.75 {
                    store.send(.moveApp(id: draggedID, after: app.id))
                } else {
                    store.send(.createFolder(name: "New Folder", appIDs: [draggedID, app.id]))
                }
            }
        }
        return true
    }
}
