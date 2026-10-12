import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers

struct FolderGridItem: View {
    let folder: Folder
    let preferences: UserPreferences
    let store: StoreOf<AppGridFeature>
    var onDragEnd: () -> Void
    var onDragStart: () -> Void = {}
    var isEditMode: Bool = false
    var hasActiveDrag: Bool = false

    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var isDraggingLocal = false
    @State private var showRenameSheet = false
    @State private var showDeleteConfirmation = false
    @State private var newFolderName = ""

    var previewApps: [AppItem] {
        // O(1) lookup via appMap, with custom names applied
        folder.appIDs.prefix(4).compactMap { id -> AppItem? in
            guard let app = store.appMap[id] else { return nil }
            return app.applyingCustomName(from: store.preferences)
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isDropTargeted ? 0.25 : 0.12))
                    .frame(width: preferences.iconSize, height: preferences.iconSize)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                ZStack {
                    // Edit-mode delete badge (folders only hold references, so
                    // deleting one just returns its apps to the grid — always safe).
                    if isEditMode {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 16))
                                        .background(Circle().fill(.white))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete folder \(folder.name)")
                            }
                            Spacer()
                        }
                        .frame(width: preferences.iconSize, height: preferences.iconSize)
                        .zIndex(1)
                    }

                    Group {
                    if previewApps.isEmpty {
                        Image(systemName: "folder")
                            .font(.system(size: preferences.iconSize * 0.4))
                            .foregroundStyle(.white.opacity(0.3))
                    } else {
                        let previewSize = preferences.iconSize * 0.37
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 2
                        ) {
                            ForEach(previewApps) { app in
                                AppIconView(
                                    app: app,
                                    size: CGFloat(previewSize),
                                    rasterPointSize: CGFloat(UserPreferences.iconRasterPointSize(preferences.iconSize))
                                )
                            }
                        }
                        .padding(6)
                        .frame(width: preferences.iconSize, height: preferences.iconSize)
                    }
                    }
                }
                .jiggling(active: isEditMode)
                .opacity(isDraggingLocal ? 0.4 : 1.0)
            }
            .keyboardSelected(store.keyboardSelectedID == folder.id)
            .scaleEffect(isHovered ? CGFloat(UserPreferences.iconHoverScale) : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)

            Text(folder.name)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: preferences.iconSize + 12)
        }
        .frame(width: preferences.iconSize + 20)
        .accessibilityLabel("\(folder.name), \(folder.appIDs.count) apps")
        .accessibilityAddTraits(.isButton)
        .onHover { isHovered = $0 }
        // Gated so tapping the delete badge in edit mode doesn't also open
        // the folder (the tap would otherwise bubble to this parent handler).
        .onTapGesture {
            if !isEditMode {
                store.send(.openFolder(folder.id))
            }
        }
        .contextMenu {
            Button("Rename Folder") {
                newFolderName = folder.name
                showRenameSheet = true
            }
            Divider()
            Button("Delete Folder", role: .destructive) {
                store.send(.deleteFolder(id: folder.id))
            }
        }
        // Drag the folder itself (reorder, Fix 8) with a prefixed payload so
        // drop sites can distinguish folder drags from app drags.
        .onDrag {
            onDragStart()
            isDraggingLocal = true
            return GridDragPayload.folderProvider(folder.id)
        }
        // Accept dropped apps into this folder (any mode, classic behavior);
        // folder-on-folder drops reorder by horizontal half (edit mode only).
        .onDrop(of: [.text], delegate: PayloadDropDelegate(
            onEnter: { isDropTargeted = true },
            onExit: { isDropTargeted = false },
            // No valid drop exists in normal mode (folder reorder is
            // edit-only), so decline upfront instead of showing a
            // misleading move cursor that later no-ops.
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
        .confirmationDialog(
            "Delete folder \"\(folder.name)\"? Its apps stay in the grid.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Folder", role: .destructive) {
                store.send(.deleteFolder(id: folder.id))
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showRenameSheet) {
            VStack(spacing: 16) {
                Text("Rename Folder")
                    .font(.headline)

                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                HStack {
                    Button("Cancel") {
                        showRenameSheet = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.send(.renameFolder(id: folder.id, name: newFolderName))
                        }
                        showRenameSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 280)
        }
    }

    private func handleDrop(at location: CGPoint, providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            onDragEnd()
            return false
        }
        // Tile width is deterministic, so the x offset splits leading/trailing
        // for folder reorder — no GeometryReader needed.
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                defer {
                    onDragEnd()
                    isDropTargeted = false
                }
                // Read mode/size live from the store: the view's captured
                // copies may be stale if edit mode or icon size changed
                // between drop and this async callback.
                let midX = (store.preferences.iconSize + 20) / 2
                switch GridDragPayload.decode(item) {
                case let .app(uuid):
                    store.send(.addAppToFolder(appID: uuid, folderID: folder.id))
                case let .folder(draggedID):
                    guard store.isEditMode, draggedID != folder.id else { return }
                    if location.x < midX {
                        store.send(.moveFolderBefore(id: draggedID, before: folder.id))
                    } else {
                        store.send(.moveFolderAfter(id: draggedID, after: folder.id))
                    }
                case nil:
                    break
                }
            }
        }
        return true
    }
}
