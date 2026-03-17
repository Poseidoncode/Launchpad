import ComposableArchitecture
import Foundation
import AppKit

@Reducer
struct FolderFeature {
    @ObservableState
    struct State: Equatable {
        var folders: [Folder]
        var selectedFolderID: String? = nil
        var currentFolder: Folder? = nil
    }
    
    enum Action {
        case selectFolder(String)
        case setFolder(Folder?)
        case renameFolder(id: String, newName: String)
        case addApp(folderId: String, app: AppItem)
        case removeApp(folderId: String, appId: String)
        case close
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectFolder(id):
                state.selectedFolderID = id
                state.currentFolder = state.folders.first { $0.id.uuidString == id }
                return .none
             
            case let .setFolder(folder):
                state.currentFolder = folder
                state.selectedFolderID = folder?.id.uuidString
                return .none
                
            case let .renameFolder(id, newName):
                if let idx = state.folders.firstIndex(where: { $0.id.uuidString == id }) {
                    state.folders[idx].name = newName
                    if state.currentFolder?.id.uuidString == id {
                        state.currentFolder?.name = newName
                    }
                }
                return .none
                
            case let .addApp(folderId, app):
                if let idx = state.folders.firstIndex(where: { $0.id.uuidString == folderId }) {
                    if !state.folders[idx].appIDs.contains(app.id) {
                        state.folders[idx].appIDs.append(app.id)
                    }
                }
                return .none
                
            case let .removeApp(folderId, appId):
                guard let uuid = UUID(uuidString: appId) else { return .none }
                if let idx = state.folders.firstIndex(where: { $0.id.uuidString == folderId }) {
                    state.folders[idx].appIDs.removeAll { $0 == uuid }
                }
                return .none
                
            case .close:
                state.currentFolder = nil
                state.selectedFolderID = nil
                return .none
            }
        }
    }
}