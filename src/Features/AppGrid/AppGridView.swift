import SwiftUI
import ComposableArchitecture
import AppKit

struct AppGridView: View {
    @Bindable var store: StoreOf<AppGridFeature>
    @State private var draggingApp: AppItem?
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
                                    preferences: store.preferences,
                                    store: store,
                                    isEditMode: store.isEditMode
                                )
                            }
                            // Apps
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.send(.flushPendingSave)
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
                    try? await Task.sleep(for: .seconds(4))
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
