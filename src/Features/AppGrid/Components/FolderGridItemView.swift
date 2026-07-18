import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers

struct FolderGridItem: View {
    let folder: Folder
    let preferences: UserPreferences
    let store: StoreOf<AppGridFeature>
    let isEditMode: Bool

    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var showRenameSheet = false
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
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: previewSize, height: previewSize)
                                }
                            }
                        }
                        .padding(6)
                        .frame(width: preferences.iconSize, height: preferences.iconSize)
                    }
                }
            }
            .scaleEffect(isHovered ? 1.10 : 1.0)
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
        .onTapGesture { store.send(.openFolder(folder.id)) }
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
        // Accept dropped apps into this folder
        .onDrop(of: [UTType.text], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }

            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    guard let draggedIDStr = draggedIDString(from: item),
                          let uuid = UUID(uuidString: draggedIDStr) else { return }

                    store.send(.addAppToFolder(appID: uuid, folderID: folder.id))
                }
            }
            return true
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
}
