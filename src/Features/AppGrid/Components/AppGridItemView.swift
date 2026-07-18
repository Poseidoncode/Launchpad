import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers
import OSLog

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

                Group {
                    if let icon = app.icon {
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
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.35), radius: isHovered ? 10 : 4, y: isHovered ? 5 : 2)
                .scaleEffect(isHovered ? 1.10 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
                .opacity(isDraggingLocal ? 0.4 : 1.0)

                // Edit mode indicator
                if isEditMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 16))
                                .background(Circle().fill(.white))
                        }
                        Spacer()
                    }
                    .frame(width: iconSize, height: iconSize)
                }
            }

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
        .accessibilityHint("Double-click to launch")
        .onHover { isHovered = $0 }
        .onTapGesture {
            if !isEditMode {
                store.send(.launchApp(app))
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
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                Text(app.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        // Drop support
        .onDrop(of: [UTType.text], isTargeted: $isCurrentDropTarget) { providers in
            guard let provider = providers.first else {
                resetDragState()
                return false
            }

            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    defer { resetDragState() }

                    guard let draggedIDStr = draggedIDString(from: item),
                          let draggedID = UUID(uuidString: draggedIDStr),
                          draggedID != app.id else { return }

                    if isEditMode {
                        store.send(.createFolder(name: "New Folder", appIDs: [draggedID, app.id]))
                    } else {
                        store.send(.moveApp(id: draggedID, after: app.id))
                    }
                }
            }
            return true
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
                do {
                    try FileManager.default.trashItem(at: app.path, resultingItemURL: nil)
                    store.send(.reloadApps)
                } catch {
                    Logger.appGrid.error("Trash failed for \(app.path.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
                    store.send(.setErrorMessage("Could not move \"\(app.name)\" to Trash. Check file permissions."))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func resetDragState() {
        onDragEnd()
        isDraggingLocal = false
        isCurrentDropTarget = false
    }
}
