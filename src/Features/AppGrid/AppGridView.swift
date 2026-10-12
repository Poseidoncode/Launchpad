import SwiftUI
import ComposableArchitecture
import AppKit
import UniformTypeIdentifiers

/// Holds the Option-hold edit-mode monitor so the NSEvent token and the
/// "entered via Option" flag survive view re-renders (a struct can't keep
/// either). Lives as a @StateObject in AppGridView.
final class OptionEditState: ObservableObject {
    var active = false
    private var monitor: Any?

    func start(store: StoreOf<AppGridFeature>) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let optionDown = event.modifierFlags.contains(.option)
            // Only claim edit mode we entered ourselves: a manual edit mode
            // (toolbar / long-press) must survive an Option tap.
            if optionDown && !store.isEditMode && !self.active {
                self.active = true
                store.send(.setEditMode(true))
            } else if !optionDown && self.active {
                self.active = false
                store.send(.setEditMode(false))
            }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        active = false
    }
}

struct AppGridView: View {
    @Bindable var store: StoreOf<AppGridFeature>
    @State private var draggingApp: AppItem?
    @State private var draggingFolderID: UUID?
    @StateObject private var optionEdit = OptionEditState()
    @FocusState private var isSearchFocused: Bool

    /// Flattened keyboard order: folders first (as laid out), then apps.
    private var keyboardOrder: [UUID] {
        displayedFolders.map(\.id) + store.displayedApps.map(\.id)
    }

    private var hasActiveDrag: Bool {
        draggingApp != nil || draggingFolderID != nil
    }

    /// Arrow-key navigation over the flattened grid order. Skipped while the
    /// folder modal is open (its own search field owns the arrows) and while
    /// the main search field is focused (arrows move the caret there).
    private func moveKeyboardSelection(by delta: Int) -> KeyPress.Result {
        guard store.openFolderID == nil, !isSearchFocused else { return .ignored }
        let order = keyboardOrder
        guard !order.isEmpty else { return .ignored }
        let next: Int
        if let selected = store.keyboardSelectedID,
           let index = order.firstIndex(of: selected) {
            next = min(max(index + delta, 0), order.count - 1)
        } else {
            next = delta > 0 ? 0 : order.count - 1
        }
        store.send(.setKeyboardSelectedID(order[next]))
        return .handled
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(store.preferences.columns, 1))
    }

    private var displayedFolders: [Folder] {
        store.searchQuery.isEmpty
            ? store.folders
            : store.folders.filter { $0.name.localizedCaseInsensitiveContains(store.searchQuery) }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── Toolbar ──────────────────────────────────────────
                HStack(spacing: 14) {
                    // Edit mode toggle (long-press an icon or hold Option also works)
                    ToolbarButton(
                        icon: store.isEditMode ? "checkmark.circle.fill" : "pencil",
                        isActive: store.isEditMode,
                        accessibilityLabel: "Toggle Edit Mode"
                    ) {
                        store.send(.toggleEditMode)
                    }
                    
                    // New Folder
                    ToolbarButton(icon: "folder.badge.plus", accessibilityLabel: "New Folder") {
                        store.send(.createFolder(name: "New Folder", appIDs: []))
                    }
                    // Refresh
                    ToolbarButton(icon: "arrow.clockwise", accessibilityLabel: "Refresh Apps") {
                        store.send(.reloadApps)
                    }
                    
                    Spacer()
                    
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.system(size: 13))
                        TextField("", text: $store.searchQuery.sending(\.setSearchQuery))
                            .accessibilityLabel("Search apps")
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
                        Text("Edit Mode: Drop on an icon's center to make a folder, on its edge to reorder")
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
                } else if store.displayedApps.isEmpty && displayedFolders.isEmpty && !store.searchQuery.isEmpty {
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
                            ForEach(displayedFolders) { folder in
                                FolderGridItem(
                                    folder: folder,
                                    preferences: store.preferences,
                                    store: store,
                                    onDragEnd: { draggingFolderID = nil },
                                    onDragStart: { draggingFolderID = folder.id },
                                    isEditMode: store.isEditMode,
                                    hasActiveDrag: hasActiveDrag
                                )
                            }
                            // Apps
                            ForEach(store.displayedApps, id: \.id) { app in
                                AppGridItem(
                                    app: app,
                                    isEditMode: store.isEditMode,
                                    hasActiveDrag: hasActiveDrag,
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
            
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
        .onAppear {
            store.send(.onAppear)
            optionEdit.start(store: store)
        }
        .onDisappear { optionEdit.stop() }
        // Auto-refresh when installs / uninstalls touch the app directories.
        .onReceive(NotificationCenter.default.publisher(for: .launchpadAppsDidChange)) { _ in
            store.send(.externalAppsChanged)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.send(.flushPendingSave)
        }
        // Scale is part of icon rasterization; refresh so grid items don't keep soft bitmaps.
        // Silent and non-forced: no-op display changes are a cheap cache hit.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            store.send(.refreshIconsAfterScreenChange)
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchpadMemoryPressure)) { _ in
            store.send(.memoryPressureReceived)
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
        // Classic search behavior: Enter launches the top hit (selected item
        // first, then the first app, then the first folder).
        .onKeyPress(.return) {
            guard store.openFolderID == nil else { return .ignored }
            if let selected = store.keyboardSelectedID {
                if displayedFolders.contains(where: { $0.id == selected }) {
                    store.send(.openFolder(selected))
                    return .handled
                }
                if let app = store.displayedApps.first(where: { $0.id == selected }) {
                    store.send(.launchApp(app))
                    return .handled
                }
            }
            if let first = store.displayedApps.first {
                store.send(.launchApp(first))
                return .handled
            }
            if let firstFolder = displayedFolders.first {
                store.send(.openFolder(firstFolder.id))
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) { moveKeyboardSelection(by: -1) }
        .onKeyPress(.rightArrow) { moveKeyboardSelection(by: 1) }
        .onKeyPress(.upArrow) { moveKeyboardSelection(by: -max(store.preferences.columns, 1)) }
        .onKeyPress(.downArrow) { moveKeyboardSelection(by: max(store.preferences.columns, 1)) }
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
        .onDrop(of: [UTType.text], isTargeted: .constant(false)) { providers in
            guard let provider = providers.first else {
                draggingApp = nil
                draggingFolderID = nil
                return false
            }
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    defer {
                        draggingApp = nil
                        draggingFolderID = nil
                    }
                    // Dragged out of the open folder onto empty space (the dim
                    // backdrop has no handler, so drops land here) → remove it.
                    // Classic Launchpad drag-out-to-remove behavior.
                    guard case let .app(draggedID) = GridDragPayload.decode(item),
                          let openID = store.openFolderID,
                          store.folders.first(where: { $0.id == openID })?.appIDs.contains(draggedID) == true
                    else { return }
                    store.send(.removeAppFromFolder(appID: draggedID, folderID: openID))
                }
            }
            return false
        }
        .animation(.easeOut(duration: 0.16), value: store.openFolderID)
        // Error banner — uses cancellable timer via store
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
                .task(id: error) {
                    do {
                        try await Task.sleep(for: .seconds(4))
                    } catch {
                        // A replacement or dismissal cancels this timer.
                        return
                    }
                    guard !Task.isCancelled else { return }
                    store.send(.dismissError)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.errorMessage != nil)
        // invisible button attached to main content for Cmd+F focus
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
