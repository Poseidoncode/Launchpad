import ComposableArchitecture
import Foundation
import AppKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.poseidoncode.launchpad", category: "app-grid")

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
        var errorMessage: String? = nil
        var preferences: UserPreferences = .default
        
        private(set) var displayedApps: [AppItem] = []
        var orderIndexMap: [UUID: Int] = [:]
        private(set) var appMap: [UUID: AppItem] = [:]
        
        mutating func updateDisplayedApps() {
            let query = searchQuery.lowercased()
            let filtered = query.isEmpty ? apps : apps.filter { 
                $0.name.lowercased().contains(query) 
            }
            
            // hide apps that are inside folders
            let folderAppIDs = Set(folders.flatMap(\.appIDs))
            
            var result = filtered
                .filter { !folderAppIDs.contains($0.id) }
                .map { app -> AppItem in
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
        
        // Get folder apps (O(n) via appMap)
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
        case launchResult(Bool, String)
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
        case setErrorMessage(String?)
        case dismissError
        case savePreferences
        case reloadPreferences
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
                
                return .run { [showHidden = state.preferences.showHiddenApps] send in
                    await send(.appsLoaded(await AppScanner.shared.scanApps(showHidden: showHidden)))
                }
                
            case let .appsLoaded(apps):
                state.isLoading = false
                state.apps = apps
                state.rebuildAppMap()
                
                let currentIDs = Set(apps.map(\.id))
                let orderedExistingIDs = state.appOrder.filter { currentIDs.contains($0) }
                let missingIDs = apps.map(\.id).filter { !orderedExistingIDs.contains($0) }
                let normalizedOrder = orderedExistingIDs + missingIDs
                
                // Clean up stale app IDs from folders
                for idx in state.folders.indices {
                    state.folders[idx].appIDs = state.folders[idx].appIDs.filter { currentIDs.contains($0) }
                }
                
                if normalizedOrder != state.appOrder {
                    state.appOrder = normalizedOrder
                    state.rebuildOrderIndexMap()
                    state.updateDisplayedApps()
                    return .send(.savePreferences)
                }
                
                state.updateDisplayedApps()
                return .none
                
            case let .launchApp(app):
                return .run { send in
                    let success = NSWorkspace.shared.open(app.path)
                    await send(.launchResult(success, app.name))
                }
                
            case let .launchResult(success, appName):
                if !success {
                    logger.error("Failed to launch: \(appName, privacy: .public)")
                    return .send(.setErrorMessage("Could not launch \(appName)"))
                }
                return .none
                
            case .reloadPreferences:
                state.preferences = PreferencesStore.load()
                state.folders = state.preferences.folders
                state.appOrder = state.preferences.appOrder
                state.rebuildOrderIndexMap()
                state.updateDisplayedApps()
                return .run { [showHidden = state.preferences.showHiddenApps] send in
                    await send(.appsLoaded(await AppScanner.shared.scanApps(showHidden: showHidden)))
                }
                
            case .toggleEditMode:
                state.isEditMode.toggle()
                return .none
                
            case let .swapApps(id, withID):
                guard let i1 = state.orderIndexMap[id],
                      let i2 = state.orderIndexMap[withID],
                      i1 != i2 else {
                    return .none
                }
                
                state.appOrder.swapAt(i1, i2)
                state.orderIndexMap[id] = i2
                state.orderIndexMap[withID] = i1
                state.updateDisplayedApps()
                return .send(.savePreferences)

            case let .moveApp(id, after: targetID):
                // #9 FIX: Use orderIndexMap for O(1) lookups instead of 3 linear scans
                guard let fromIndex = state.orderIndexMap[id],
                      let toIndex = state.orderIndexMap[targetID],
                      id != targetID else {
                    return .none
                }

                var updatedOrder = state.appOrder
                updatedOrder.remove(at: fromIndex)
                // Only adjust target index when moving forward (target shifts left after removal)
                let adjustedTarget = (fromIndex < toIndex) ? toIndex - 1 : toIndex
                updatedOrder.insert(id, at: adjustedTarget + 1)

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
                if state.appMap.isEmpty && !state.apps.isEmpty {
                    state.rebuildAppMap()
                }
                state.openFolderID = id
                return .none
                
            case .closeFolder:
                state.openFolderID = nil
                return .none
                
            case let .createFolder(name, appIDs):
                // auto-uniquify "New Folder" so multiple creates don't collide
                let finalName: String
                if state.folders.contains(where: { $0.name == name }) {
                    let count = state.folders.filter { $0.name.hasPrefix(name) }.count + 1
                    finalName = "\(name) \(count)"
                } else {
                    finalName = name
                }
                let folder = Folder(name: finalName, appIDs: appIDs)
                state.folders.append(folder)
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .renameFolder(id, name):
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                if let idx = state.folders.firstIndex(where: { $0.id == id }) {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    if state.folders.contains(where: { $0.name == trimmed && $0.id != id }) {
                        let count = state.folders.filter { $0.name.hasPrefix(trimmed) }.count + 1
                        state.folders[idx].name = "\(trimmed) \(count)"
                    } else {
                        state.folders[idx].name = trimmed
                    }
                }
                return .send(.savePreferences)
                
            case let .deleteFolder(id):
                state.folders.removeAll { $0.id == id }
                state.updateDisplayedApps()
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
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .removeAppFromFolder(appID, folderID):
                if let idx = state.folders.firstIndex(where: { $0.id == folderID }) {
                    state.folders[idx].appIDs.removeAll { $0 == appID }
                }
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .renameApp(bundleIdentifier, newName):
                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                state.preferences.customAppNames[bundleIdentifier] = newName
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .setErrorMessage(message):
                state.errorMessage = message
                return .none
                
            case .dismissError:
                state.errorMessage = nil
                return .none
                
            case .savePreferences:
                // debounced 300ms — rapid drag operations batch into one write
                let prefs = UserPreferences(
                    appOrder: state.appOrder,
                    folders: state.folders,
                    showHiddenApps: state.preferences.showHiddenApps,
                    iconSize: state.preferences.iconSize,
                    columns: state.preferences.columns,
                    customAppNames: state.preferences.customAppNames
                )
                return .run { _ in
                    try await Task.sleep(nanoseconds: 300_000_000)
                    PreferencesStore.save(prefs)
                } catch: { error, _ in
                    if error is CancellationError { return }
                    logger.error("Preferences save failed: \(error, privacy: .public)")
                }
                .cancellable(id: "prefs-save", cancelInFlight: true)
                
            case .reloadApps:
                state.isLoading = true
                return .run { [showHidden = state.preferences.showHiddenApps] send in
                    let apps = await AppScanner.shared.scanApps(showHidden: showHidden, forceRefresh: true)
                    await send(.appsLoaded(apps))
                }
            }
        }
    }
}
