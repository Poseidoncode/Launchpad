import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers

struct AppGridView: View {
    @Bindable var store: StoreOf<AppGridFeature>
    @State private var draggingApp: AppItem?
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 13)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Full window vibrancy background
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
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
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(width: 180)
                            .placeholder(when: store.searchQuery.isEmpty) {
                                Text("Search")
                                    .foregroundStyle(.white.opacity(0.5))
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                // Edit mode hint
                if store.isEditMode {
                    HStack {
                        Text("編輯模式：拖曳 App 以重新排序")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Button("完成") {
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
            Text("裝置")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 8)
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
        .onAppear { store.send(.onAppear) }
        .onKeyPress(.escape) {
            if store.isEditMode { 
                store.send(.toggleEditMode)
                return .handled 
            }
            if store.openFolderID != nil { store.send(.closeFolder); return .handled }
            if !store.searchQuery.isEmpty { store.send(.setSearchQuery("")); return .handled }
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
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Drop target indicator
                if isCurrentDropTarget && hasActiveDrag {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: 66, height: 66)
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
                .frame(width: 60, height: 60)
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
                    .frame(width: 60, height: 60)
                }
            }
            
            Text(app.name)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .frame(width: 80)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            // Double click to launch
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
                    
                    // Insert the dragged app after the drop target instead of swapping.
                    store.send(.moveApp(id: draggedID, after: app.id))
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
        // 使用 appMap 進行 O(1) 查找
        folder.appIDs.prefix(4).compactMap { store.appMap[$0] }
    }
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isDropTargeted ? 0.25 : 0.12))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 2
                ) {
                    ForEach(previewApps) { app in
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                        }
                    }
                }
                .padding(6)
                .frame(width: 60, height: 60)
            }
            .scaleEffect(isHovered ? 1.10 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
            
            Text(folder.name)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .frame(width: 80)
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
            
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                DispatchQueue.main.async {
                    guard let data = data as? Data,
                          let idStr = String(data: data, encoding: .utf8),
                          let uuid = UUID(uuidString: idStr) else { return }
                    
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
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    
    private var folder: Folder? {
        store.folders.first(where: { $0.id == folderID })
    }
    
    private var folderApps: [AppItem] {
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
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        if folderApps.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white.opacity(0.45))
                                Text("這個資料夾目前沒有 App")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                                Text("把 App 拖進這個資料夾後，會顯示在這裡。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .padding(.horizontal, 20)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(folderApps) { app in
                                    VStack(spacing: 5) {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 60, height: 60)
                                        }
                                        Text(app.name)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 72)
                                    }
                                    .frame(width: 80)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
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
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear { store.send(.closeFolder) }
            }
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

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
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
