import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers

struct FolderDetailView: View {
    let folderID: UUID
    let store: StoreOf<AppGridFeature>

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var folderSearchQuery = ""
    @State private var dropTargetID: UUID? = nil

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(store.preferences.columns, 1))
    }

    private var folder: Folder? {
        store.folders.first(where: { $0.id == folderID })
    }

    // Computed from store state — always fresh, no stale @State copies
    private var folderApps: [AppItem] {
        guard let folder else { return [] }
        return folder.appIDs.compactMap { id -> AppItem? in
            guard let app = store.appMap[id] else { return nil }
            return app.applyingCustomName(from: store.preferences)
        }
    }

    var body: some View {
        Group {
            if let folder {
                let filteredApps = folderSearchQuery.isEmpty
                    ? folderApps
                    : folderApps.filter { $0.name.localizedCaseInsensitiveContains(folderSearchQuery) }

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { store.send(.closeFolder) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .fontWeight(.semibold)
                                Text("Close")
                            }
                            .foregroundStyle(.white)
                            .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close folder")

                        Spacer()

                        // Editable folder name
                        if isEditingName {
                            TextField("Folder Name", text: $editedName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 100, maxWidth: 200)
                                .onSubmit {
                                    if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        store.send(.renameFolder(id: folder.id, name: editedName))
                                    }
                                    isEditingName = false
                                }

                            Button("Save") {
                                if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    store.send(.renameFolder(id: folder.id, name: editedName))
                                }
                                isEditingName = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        } else {
                            Text(folder.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .onTapGesture(count: 2) {
                                    editedName = folder.name
                                    isEditingName = true
                                }
                                .contextMenu {
                                    Button("Rename") {
                                        editedName = folder.name
                                        isEditingName = true
                                    }
                                }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    Divider()
                        .background(.white.opacity(0.2))

                    // Folder-local search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(size: 12))
                        TextField("Search in folder…", text: $folderSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                        if !folderSearchQuery.isEmpty {
                            Button(action: { folderSearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1), in: Capsule())
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    ScrollView(.vertical, showsIndicators: false) {
                        if filteredApps.isEmpty && !folderSearchQuery.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("No results in \"\(folder.name)\"")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .padding(.horizontal, 20)
                        } else if folderApps.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white.opacity(0.45))
                                Text("This folder is empty")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                                Text("Close this folder, then drag apps onto its tile to add them")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .padding(.horizontal, 20)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredApps) { app in
                                    VStack(spacing: 5) {
                                        AppIconView(
                                            app: app,
                                            size: CGFloat(store.preferences.iconSize),
                                            rasterPointSize: CGFloat(UserPreferences.iconRasterPointSize(store.preferences.iconSize))
                                        )
                                        Text(app.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: store.preferences.iconSize + 12)
                                    }
                                    .frame(width: store.preferences.iconSize + 20)
                                    .contentShape(Rectangle())
                                    .overlay {
                                        if dropTargetID == app.id {
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.accentColor, lineWidth: 3)
                                        }
                                    }
                                    .accessibilityLabel(app.name)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint("Click to launch")
                                    .onTapGesture {
                                        store.send(.launchApp(app))
                                    }
                                    .contextMenu {
                                        Button("Open") { store.send(.launchApp(app)) }
                                        Divider()
                                        Button("Remove from Folder") {
                                            store.send(.removeAppFromFolder(appID: app.id, folderID: folder.id))
                                        }
                                    }
                                    // Classic parity: drag out of the folder to
                                    // remove (drop on the dim backdrop), drag
                                    // between items to reorder within the folder.
                                    .onDrag {
                                        GridDragPayload.appProvider(app.id)
                                    }
                                    .onDrop(of: [.text], delegate: PayloadDropDelegate(
                                        onEnter: { dropTargetID = app.id },
                                        onExit: { if dropTargetID == app.id { dropTargetID = nil } },
                                        onDrop: { location, providers in
                                            handleItemDrop(
                                                at: location,
                                                providers: providers,
                                                target: app,
                                                folderID: folder.id
                                            )
                                        }
                                    ))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                        }
                    }
                }
                .frame(minWidth: 500, idealWidth: 620, minHeight: 350, idealHeight: 430)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.16).opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .background(WindowDragBlocker())
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear { store.send(.closeFolder) }
            }
        }
        .onChange(of: store.openFolderID) { dropTargetID = nil }
    }

    private func handleItemDrop(
        at location: CGPoint,
        providers: [NSItemProvider],
        target: AppItem,
        folderID: UUID
    ) -> Bool {
        guard let provider = providers.first else {
            dropTargetID = nil
            return false
        }
        // Item width matches the main grid (`iconSize + 20`); left half
        // inserts before the target, right half after. Center never nests —
        // classic Launchpad has no folders-in-folders.
        let before = location.x < (store.preferences.iconSize + 20) / 2
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                defer { dropTargetID = nil }
                guard case let .app(draggedID) = GridDragPayload.decode(item),
                      draggedID != target.id else { return }
                if store.appMap[draggedID] == nil {
                    return
                }
                // Membership is read back from the store at drop time so a
                // folder edit between drag-start and drop can't misroute.
                let isMember = store.folders
                    .first(where: { $0.id == folderID })?.appIDs.contains(draggedID) == true
                if isMember {
                    if before {
                        store.send(.moveAppInFolderBefore(id: draggedID, before: target.id, folderID: folderID))
                    } else {
                        store.send(.moveAppInFolderAfter(id: draggedID, after: target.id, folderID: folderID))
                    }
                } else {
                    // Dragged in from the main grid — join the folder.
                    store.send(.addAppToFolder(appID: draggedID, folderID: folderID))
                }
            }
        }
        return true
    }
}
