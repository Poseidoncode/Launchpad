import ComposableArchitecture
import Foundation
import AppKit

@Reducer
struct AppGridFeature {
    @ObservableState
    struct State: Equatable {
        var apps: [AppItem] = []
        var folders: [Folder] = []
        var appOrder: [UUID] = []
        var isLoading: Bool = false
        var isEditMode: Bool = false
        var searchQuery: String = ""
        var openFolderID: UUID? = nil
        var preferences: UserPreferences = .default
        
        private(set) var displayedApps: [AppItem] = []
        private var orderIndexMap: [UUID: Int] = [:]
        private(set) var appMap: [UUID: AppItem] = [:] // 改為 internal，讓 View 可以存取
        
        mutating func updateDisplayedApps() {
            let query = searchQuery.lowercased()
            let filtered = query.isEmpty ? apps : apps.filter { 
                $0.name.lowercased().contains(query) 
            }
            
            var result = filtered.map { app -> AppItem in
                if let customName = preferences.customAppNames[app.bundleIdentifier] {
                    var modifiedApp = app
                    modifiedApp.name = customName
                    return modifiedApp
                }
                return app
            }
            
            result.sort { app1, app2 in
                let i1 = orderIndexMap[app1.id] ?? Int.max
                let i2 = orderIndexMap[app2.id] ?? Int.max
                return i1 < i2
            }
            
            displayedApps = result
        }
        
        mutating func rebuildOrderIndexMap() {
            orderIndexMap = Dictionary(uniqueKeysWithValues: appOrder.enumerated().map { ($0.element, $0.offset) })
        }
        
        mutating func rebuildAppMap() {
            appMap = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        }
        
        // 快速取得 folder 的 apps（O(n) 而非 O(n*m)）
        func getFolderApps(folderID: UUID) -> [AppItem] {
            guard let folder = folders.first(where: { $0.id == folderID }) else { return [] }
            
            return folder.appIDs.compactMap { id -> AppItem? in
                guard let app = appMap[id] else { return nil }
                // Apply custom name
                if let customName = preferences.customAppNames[app.bundleIdentifier] {
                    var modifiedApp = app
                    modifiedApp.name = customName
                    return modifiedApp
                }
                return app
            }
        }
    }
    
    enum Action {
        case onAppear
        case appsLoaded([AppItem])
        case launchApp(AppItem)
        case toggleEditMode
        case swapApps(id: UUID, with: UUID)
        case moveApp(id: UUID, after: UUID)
        case setSearchQuery(String)
        case openFolder(UUID)
        case closeFolder
        case createFolder(name: String, appIDs: [UUID])
        case renameFolder(id: UUID, name: String)
        case deleteFolder(id: UUID)
        case addAppToFolder(appID: UUID, folderID: UUID)
        case removeAppFromFolder(appID: UUID, folderID: UUID)
        case renameApp(bundleIdentifier: String, newName: String)
        case savePreferences
        case reloadApps
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.preferences = PreferencesStore.load()
                state.folders = state.preferences.folders
                state.appOrder = state.preferences.appOrder
                state.rebuildOrderIndexMap()
                
                // 背景加載應用列表，避免阻塞 UI
                return .run { send in
                    await send(.appsLoaded(await AppScanner.shared.scanApps()))
                }
                
            case let .appsLoaded(apps):
                state.isLoading = false
                state.apps = apps
                state.rebuildAppMap() // 建立 ID 映射
                
                #if DEBUG
                print("[appsLoaded] Total apps: \(apps.count)")
                print("[appsLoaded] App IDs sample: \(apps.prefix(3).map { $0.id })")
                print("[appsLoaded] Folders before: \(state.folders.map { "\($0.name): \($0.appIDs.count) apps" })")
                #endif
                
                let currentIDs = Set(apps.map(\.id))
                let orderedExistingIDs = state.appOrder.filter { currentIDs.contains($0) }
                let missingIDs = apps.map(\.id).filter { !orderedExistingIDs.contains($0) }
                let normalizedOrder = orderedExistingIDs + missingIDs
                
                if normalizedOrder != state.appOrder {
                    state.appOrder = normalizedOrder
                    state.rebuildOrderIndexMap()
                    state.updateDisplayedApps()
                    return .send(.savePreferences)
                }
                
                #if DEBUG
                print("[appsLoaded] appMap keys count: \(state.appMap.count)")
                if let firstFolder = state.folders.first {
                    print("[appsLoaded] First folder appIDs: \(firstFolder.appIDs)")
                    let found = firstFolder.appIDs.compactMap { state.appMap[$0] }.count
                    print("[appsLoaded] Found in appMap: \(found)/\(firstFolder.appIDs.count)")
                }
                #endif
                
                state.updateDisplayedApps()
                return .none
                
            case let .launchApp(app):
                NSWorkspace.shared.open(app.path)
                return .none
                
            case .toggleEditMode:
                state.isEditMode.toggle()
                return .none
                
            case let .swapApps(id, withID):
                guard let i1 = state.appOrder.firstIndex(of: id),
                      let i2 = state.appOrder.firstIndex(of: withID),
                      i1 != i2 else { 
                    return .none 
                }
                
                state.appOrder.swapAt(i1, i2)
                state.rebuildOrderIndexMap()
                state.updateDisplayedApps()
                return .send(.savePreferences)

            case let .moveApp(id, after: targetID):
                guard let fromIndex = state.appOrder.firstIndex(of: id),
                      state.appOrder.contains(targetID),
                      id != targetID else {
                    return .none
                }

                var updatedOrder = state.appOrder
                updatedOrder.remove(at: fromIndex)

                guard let adjustedTargetIndex = updatedOrder.firstIndex(of: targetID) else {
                    return .none
                }

                let insertionIndex = adjustedTargetIndex + 1
                updatedOrder.insert(id, at: insertionIndex)

                if updatedOrder == state.appOrder {
                    return .none
                }

                state.appOrder = updatedOrder
                state.rebuildOrderIndexMap()
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .setSearchQuery(query):
                state.searchQuery = query
                state.updateDisplayedApps()
                return .none
                
            case let .openFolder(id):
                // 強制確保 appMap 已經建立
                if state.appMap.isEmpty && !state.apps.isEmpty {
                    state.rebuildAppMap()
                }
                #if DEBUG
                print("[openFolder] openFolderID: \(id)")
                print("[openFolder] appMap count: \(state.appMap.count)")
                if let folder = state.folders.first(where: { $0.id == id }) {
                    print("[openFolder] folder appIDs: \(folder.appIDs)")
                    let found = folder.appIDs.filter { state.appMap[$0] != nil }.count
                    print("[openFolder] found in appMap: \(found)/\(folder.appIDs.count)")
                }
                #endif
                state.openFolderID = id
                return .none
                
            case .closeFolder:
                state.openFolderID = nil
                return .none
                
            case let .createFolder(name, appIDs):
                let folder = Folder(name: name, appIDs: appIDs)
                state.folders.append(folder)
                return .send(.savePreferences)
                
            case let .renameFolder(id, name):
                if let idx = state.folders.firstIndex(where: { $0.id == id }) {
                    state.folders[idx].name = name
                }
                return .send(.savePreferences)
                
            case let .deleteFolder(id):
                state.folders.removeAll { $0.id == id }
                if state.openFolderID == id {
                    state.openFolderID = nil
                }
                return .send(.savePreferences)
                
            case let .addAppToFolder(appID, folderID):
                if let idx = state.folders.firstIndex(where: { $0.id == folderID }) {
                    if !state.folders[idx].appIDs.contains(appID) {
                        state.folders[idx].appIDs.append(appID)
                    }
                }
                return .send(.savePreferences)
                
            case let .removeAppFromFolder(appID, folderID):
                if let idx = state.folders.firstIndex(where: { $0.id == folderID }) {
                    state.folders[idx].appIDs.removeAll { $0 == appID }
                }
                return .send(.savePreferences)
                
            case let .renameApp(bundleIdentifier, newName):
                state.preferences.customAppNames[bundleIdentifier] = newName
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case .savePreferences:
                let prefs = UserPreferences(
                    appOrder: state.appOrder,
                    folders: state.folders,
                    showHiddenApps: state.preferences.showHiddenApps,
                    iconSize: state.preferences.iconSize,
                    columns: state.preferences.columns,
                    customAppNames: state.preferences.customAppNames
                )
                PreferencesStore.save(prefs)
                return .none
                
            case .reloadApps:
                state.isLoading = true
                return .run { send in
                    let apps = await AppScanner.shared.scanApps(forceRefresh: true)
                    await send(.appsLoaded(apps))
                }
            }
        }
    }
}
