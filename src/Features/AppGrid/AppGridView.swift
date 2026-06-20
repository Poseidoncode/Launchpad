import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.launchpad.app", category: "app-grid-view")

struct AppGridView: View {
    @Bindable var store: StoreOf<AppGridFeature>
    @State private var draggingApp: AppItem?
    @State private var lastPrefData: Data?
    @FocusState private var isSearchFocused: Bool
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(store.preferences.columns, 1))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── Toolbar ──────────────────────────────────────────
                HStack(spacing: 14) {
                    // Sort/Edit mode toggle button
                    ToolbarButton(
                        icon: store.isEditMode ? "checkmark.circle.fill" : "arrow.up.arrow.down",
                        isActive: store.isEditMode
                    ) {
                        store.send(.toggleEditMode)
                    }
                    
                    // New Folder
                    ToolbarButton(icon: "folder.badge.plus") {
                        store.send(.createFolder(name: "New Folder", appIDs: []))
                    }
                    // Refresh
                    ToolbarButton(icon: "arrow.clockwise") {
                        store.send(.reloadApps)
                    }
                    
                    Spacer()
                    
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.system(size: 13))
                        TextField("", text: $store.searchQuery.sending(\.setSearchQuery))
                            .focused($isSearchFocused)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(store.openFolderID != nil ? 0.3 : 1))
                            .frame(width: 180)
                            .disabled(store.openFolderID != nil)
                            .placeholder(when: store.searchQuery.isEmpty) {
                                Text("Search")
                                    .foregroundStyle(.white.opacity(store.openFolderID != nil ? 0.2 : 0.5))
                                    .font(.system(size: 13))
                            }
                        if !store.searchQuery.isEmpty {
                            Button(action: { store.send(.setSearchQuery("")) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .opacity(store.openFolderID != nil ? 0.5 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                // Edit mode hint
                if store.isEditMode {
                    HStack {
                        Text("Edit Mode: Drag apps to reorder")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Button("Done") {
                            store.send(.toggleEditMode)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                
                // ── Main Grid ────────────────────────────────────────
                if store.isLoading {
                    Spacer()
                    ProgressView().tint(.white).scaleEffect(1.5)
                    Spacer()
                } else if store.displayedApps.isEmpty && !store.searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No Results for \"\(store.searchQuery)\"")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Try a different search term")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.displayedApps.isEmpty && store.folders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No Applications Found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Make sure apps are installed in /Applications")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: gridColumns, spacing: 20) {
                            // Folders first
                            ForEach(store.folders) { folder in
                                FolderGridItem(
                                    folder: folder,
                                    allApps: store.apps,
                                    preferences: store.preferences,
                                    store: store,
                                    isEditMode: store.isEditMode
                                )
                            }
                            // Apps - Adding explicit ID to ensure proper view updates when order changes
                            ForEach(store.displayedApps, id: \.id) { app in
                                AppGridItem(
                                    app: app,
                                    isEditMode: store.isEditMode,
                                    hasActiveDrag: draggingApp != nil,
                                    store: store,
                                    onDragStart: {
                                        draggingApp = app
                                    },
                                    onDragEnd: { 
                                        draggingApp = nil
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 48)
                    }
                }
            }
            
            // ── Bottom device label ──────────────────────────────────
            Text("Device")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 8)
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
        .onAppear { store.send(.onAppear) }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)) { _ in
            let currentData = UserDefaults.standard.data(forKey: "LaunchpadUserPreferences")
            guard currentData != nil, currentData != lastPrefData else { return }
            lastPrefData = currentData
            store.send(.reloadPreferences)
        }
        .onKeyPress(.escape) {
            if store.openFolderID != nil { store.send(.closeFolder); return .handled }
            if !store.searchQuery.isEmpty { store.send(.setSearchQuery("")); return .handled }
            if store.isEditMode { 
                store.send(.toggleEditMode)
                return .handled 
            }
            return .ignored
        }
        .overlay {
            if let folderID = store.openFolderID {
                ZStack {
                    Color.black
                        .opacity(0.32)
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.closeFolder)
                        }
                    
                    FolderDetailView(folderID: folderID, store: store)
                        .id(folderID)
                        .padding(32)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .animation(.easeOut(duration: 0.16), value: store.openFolderID)
        // Error banner
        .overlay(alignment: .top) {
            if let error = store.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        store.send(.dismissError)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        store.send(.dismissError)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.errorMessage != nil)
        // ponytail: invisible button attached to main content for Cmd+F focus
        .background {
            Button("") { isSearchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - App Grid Item

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
                do {
                    try NSWorkspace.shared.recycle([app.path])
                    store.send(.reloadApps)
                } catch {
                    logger.error("Failed to move to trash: \(error.localizedDescription, privacy: .public)")
                }
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
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    defer { 
                        onDragEnd()
                        isDraggingLocal = false
                        isCurrentDropTarget = false
                    }
                    
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
    }
}

// MARK: - Folder Grid Item

struct FolderGridItem: View {
    let folder: Folder
    let allApps: [AppItem]
    let preferences: UserPreferences
    let store: StoreOf<AppGridFeature>
    let isEditMode: Bool
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var showRenameSheet = false
    @State private var newFolderName = ""
    
    var previewApps: [AppItem] {
        // O(1) lookup via appMap
        folder.appIDs.prefix(4).compactMap { store.appMap[$0] }
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

// MARK: - Folder Detail View (Modal)

struct FolderDetailView: View {
    let folderID: UUID
    let store: StoreOf<AppGridFeature>
    
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var folderApps: [AppItem] = []
    @State private var folderSearchQuery = ""
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(store.preferences.columns, 1))
    }
    
    private var folder: Folder? {
        store.folders.first(where: { $0.id == folderID })
    }
    

    
    var body: some View {
        Group {
            if let folder {
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
                        let filteredApps = folderSearchQuery.isEmpty
                            ? folderApps
                            : folderApps.filter { $0.name.localizedCaseInsensitiveContains(folderSearchQuery) }
                        
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
                                Text("Drag apps here to add them to this folder")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .padding(.horizontal, 20)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(filteredApps) { app in
                                    VStack(spacing: 5) {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: store.preferences.iconSize, height: store.preferences.iconSize)
                                        }
                                        Text(app.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: store.preferences.iconSize + 12)
                                    }
                                    .frame(width: store.preferences.iconSize + 20)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel(app.name)
                                    .accessibilityAddTraits(.isButton)
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
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                        }
                    }
                }
                .frame(width: 620, height: 430)
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
                .onAppear { folderApps = computeFolderApps() }
                .onChange(of: store.folders) { _, _ in
                    folderApps = computeFolderApps()
                }
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear { store.send(.closeFolder) }
            }
        }
    }
    
    private func computeFolderApps() -> [AppItem] {
        guard let folder else { return [] }
        return folder.appIDs.compactMap { id -> AppItem? in
            guard let app = store.appMap[id] else { return nil }
            if let customName = store.preferences.customAppNames[app.bundleIdentifier] {
                var modifiedApp = app
                modifiedApp.name = customName
                return modifiedApp
            }
            return app
        }
    }
}

// MARK: - Helpers

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

// MARK: - Shared Helpers

private func draggedIDString(from item: NSSecureCoding?) -> String? {
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

struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NonDraggableNSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
