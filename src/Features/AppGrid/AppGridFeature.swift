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
    }
    
    enum Action {
        case onAppear
        case appsLoaded([AppItem])
        case launchApp(AppItem)
        case toggleEditMode
        case swapApps(id: UUID, with: UUID)
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
                return .run { send in
                    let apps = await AppScanner.shared.scanApps()
                    await send(.appsLoaded(apps))
                }
                
            case let .appsLoaded(apps):
                state.isLoading = false
                state.apps = apps
                
                let currentIDs = Set(apps.map(\.id))
                let orderedExistingIDs = state.appOrder.filter { currentIDs.contains($0) }
                let missingIDs = apps.map(\.id).filter { !orderedExistingIDs.contains($0) }
                let normalizedOrder = orderedExistingIDs + missingIDs
                
                if normalizedOrder != state.appOrder {
                    state.appOrder = normalizedOrder
                    return .send(.savePreferences)
                }
                
                return .none
                
            case let .launchApp(app):
                NSWorkspace.shared.open(app.path)
                return .none
                
            case .toggleEditMode:
                state.isEditMode.toggle()
                return .none
                
            case let .swapApps(id, withID):
                // Ensure both IDs exist in the appOrder array before swapping
                guard let i1 = state.appOrder.firstIndex(of: id),
                      let i2 = state.appOrder.firstIndex(of: withID),
                      i1 != i2 else { // Avoid unnecessary swaps
                    return .none
                }
                
                state.appOrder.swapAt(i1, i2)
                
                // Return a sequence of actions: save preferences and potentially trigger UI refresh
                return .send(.savePreferences)
                
            case let .setSearchQuery(query):
                state.searchQuery = query
                return .none
                
            case let .openFolder(id):
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
                    let apps = await AppScanner.shared.scanApps()
                    await send(.appsLoaded(apps))
                }
            }
        }
    }
}
