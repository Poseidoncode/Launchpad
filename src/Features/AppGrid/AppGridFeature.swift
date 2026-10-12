import ComposableArchitecture
import Foundation
import AppKit
import OSLog

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
        /// Keyboard-driven selection for arrow-key navigation (never persisted).
        var keyboardSelectedID: UUID? = nil
        var preferences: UserPreferences = .default
        
        private(set) var displayedApps: [AppItem] = []
        var orderIndexMap: [UUID: Int] = [:]
        private(set) var appMap: [UUID: AppItem] = [:]
        
        mutating func updateDisplayedApps() {
            // Locale-aware matching avoids allocating lowercased copies on each keystroke.
            let filtered = searchQuery.isEmpty ? apps : apps.filter { app in
                let displayName = preferences.customAppNames[app.bundleIdentifier] ?? app.name
                return displayName.localizedCaseInsensitiveContains(searchQuery)
            }
            // Keep apps inside folders hidden in the normal grid, but include them
            // in search results so users can find apps without opening each folder.
            let folderAppIDs = searchQuery.isEmpty ? Set(folders.flatMap(\.appIDs)) : []
            var result = filtered.filter { !folderAppIDs.contains($0.id) }
            // Skip copying the whole array when no custom names exist (common).
            if !preferences.customAppNames.isEmpty {
                result = result.map { $0.applyingCustomName(from: preferences) }
            }
            
            result.sort { app1, app2 in
                let i1 = orderIndexMap[app1.id] ?? Int.max
                let i2 = orderIndexMap[app2.id] ?? Int.max
                return i1 < i2
            }
            
            displayedApps = result
            // Prune a keyboard selection that no longer points at anything
            // visible (trashed app, foldered-away app). Folder selections are
            // kept: folders live outside displayedApps by design.
            if let selected = keyboardSelectedID,
               !displayedApps.contains(where: { $0.id == selected }),
               !folders.contains(where: { $0.id == selected }) {
                keyboardSelectedID = nil
            }
        }
        
        mutating func rebuildOrderIndexMap() {
            // Preferences can be hand-edited or left by older versions; tolerate
            // duplicate IDs rather than trapping in Dictionary(uniqueKeysWithValues:).
            var indices: [UUID: Int] = [:]
            for (index, id) in appOrder.enumerated() where indices[id] == nil {
                indices[id] = index
            }
            orderIndexMap = indices
        }
        
        mutating func rebuildAppMap() {
            var map: [UUID: AppItem] = [:]
            for app in apps where map[app.id] == nil {
                map[app.id] = app
            }
            appMap = map
        }
    }
    
    enum Action {
        case onAppear
        /// - Parameter clearsLoading: Only scans that showed a spinner
        ///   (`.onAppear`, `.reloadApps`) clear it. Background scans (settings
        ///   rescan, screen-change refresh, debounced icon rescan) pass `false`
        ///   so they can't end a concurrent reload's spinner early.
        case appsLoaded([AppItem], clearsLoading: Bool = true)
        case launchApp(AppItem)
        case launchResult(Bool, String)
        case trashApp(AppItem)
        case appWasTrashed(UUID)
        case toggleEditMode
        case setEditMode(Bool)
        case swapApps(id: UUID, with: UUID)
        case moveApp(id: UUID, after: UUID)
        case moveAppBefore(id: UUID, before: UUID)
        case moveFolderAfter(id: UUID, after: UUID)
        case moveFolderBefore(id: UUID, before: UUID)
        case moveAppInFolderAfter(id: UUID, after: UUID, folderID: UUID)
        case moveAppInFolderBefore(id: UUID, before: UUID, folderID: UUID)
        case setKeyboardSelectedID(UUID?)
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
        case flushPendingSave
        case reloadApps
        case externalAppsChanged
        case refreshIconsAfterScreenChange
        case memoryPressureReceived
        case iconRescanDebounceFired
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
                
                return .run { [
                    showHidden = state.preferences.showHiddenApps,
                    iconSize = state.preferences.iconSize
                ] send in
                    await send(.appsLoaded(await AppScanner.shared.scanApps(
                        showHidden: showHidden,
                        iconSize: iconSize
                    )))
                }
                
            case let .appsLoaded(apps, clearsLoading):
                if clearsLoading {
                    state.isLoading = false
                }
                state.apps = apps
                state.keyboardSelectedID = nil
                state.rebuildAppMap()
                
                var orderedIDs = Set<UUID>()
                // Keep IDs not seen in this scan: hidden apps (and temporarily
                // inaccessible apps) must not lose their saved order when omitted.
                let orderedExistingIDs = state.appOrder.filter { orderedIDs.insert($0).inserted }
                let missingIDs = apps.map(\.id).filter { orderedIDs.insert($0).inserted }
                let normalizedOrder = orderedExistingIDs + missingIDs
                
                // Keep unavailable folder members for the same reason. Remove only
                // duplicate folder identities and duplicate app memberships.
                var foldersChanged = false
                var seenFolderIDs = Set<UUID>()
                let uniqueFolders = state.folders.filter { seenFolderIDs.insert($0.id).inserted }
                if uniqueFolders.count != state.folders.count {
                    state.folders = uniqueFolders
                    foldersChanged = true
                }
                var assignedAppIDs = Set<UUID>()
                for idx in state.folders.indices {
                    let normalizedIDs = state.folders[idx].appIDs.filter {
                        assignedAppIDs.insert($0).inserted
                    }
                    if normalizedIDs != state.folders[idx].appIDs {
                        state.folders[idx].appIDs = normalizedIDs
                        foldersChanged = true
                    }
                }
                
                let orderChanged = normalizedOrder != state.appOrder
                if orderChanged {
                    state.appOrder = normalizedOrder
                    state.rebuildOrderIndexMap()
                }
                state.updateDisplayedApps()
                return orderChanged || foldersChanged ? .send(.savePreferences) : .none
                
            case let .launchApp(app):
                return .run { send in
                    let success = NSWorkspace.shared.open(app.path)
                    if success {
                        // Classic Launchpad dismisses itself on launch so the
                        // launched app comes forward instead of hiding behind us.
                        await MainActor.run { NSApplication.shared.hide(nil) }
                    }
                    await send(.launchResult(success, app.name))
                }
                
            case let .launchResult(success, appName):
                if !success {
                    Logger.appGrid.error("Failed to launch: \(appName, privacy: .private)")
                    return .send(.setErrorMessage("Could not launch \(appName)"))
                }
                // Dismiss the folder modal so the just-launched app isn't hidden
                // behind it. No-op when launching from the main grid; kept open
                // on failure so the user can retry and still see the context.
                state.openFolderID = nil
                return .none

            case let .trashApp(app):
                let appName = app.name
                let appPath = app.path
                let appID = app.id
                return .run { send in
                    do {
                        try await Task.detached(priority: .userInitiated) {
                            try FileManager.default.trashItem(at: appPath, resultingItemURL: nil)
                        }.value
                        await send(.appWasTrashed(appID))
                        await send(.reloadApps)
                    } catch {
                        Logger.appGrid.error("Trash failed for \(appPath.path, privacy: .private): \(error.localizedDescription, privacy: .private)")
                        await send(.setErrorMessage("Could not move \"\(appName)\" to Trash. Try Finder or check file permissions."))
                    }
                }

            case let .appWasTrashed(appID):
                let hadApp = state.apps.contains { $0.id == appID }
                let orderCount = state.appOrder.count
                state.apps.removeAll { $0.id == appID }
                state.appOrder.removeAll { $0 == appID }
                var foldersChanged = false
                // Snapshot BEFORE removal: only folders that held the trashed
                // app may be dropped if they end up empty. An unrelated empty
                // folder (e.g. created from the toolbar) must survive.
                let foldersHoldingTrashedApp = Set(state.folders.filter { $0.appIDs.contains(appID) }.map(\.id))
                for idx in state.folders.indices {
                    let originalIDs = state.folders[idx].appIDs
                    state.folders[idx].appIDs.removeAll { $0 == appID }
                    foldersChanged = foldersChanged || originalIDs != state.folders[idx].appIDs
                }
                // Drop folders emptied by this trash, mirroring removeAppFromFolder.
                let survivingFolders = state.folders.filter { !$0.appIDs.isEmpty || !foldersHoldingTrashedApp.contains($0.id) }
                if survivingFolders.count != state.folders.count {
                    if let openID = state.openFolderID,
                       foldersHoldingTrashedApp.contains(openID),
                       survivingFolders.first(where: { $0.id == openID }) == nil {
                        state.openFolderID = nil
                    }
                    state.folders = survivingFolders
                    foldersChanged = true
                }
                guard hadApp || orderCount != state.appOrder.count || foldersChanged else { return .none }
                state.rebuildAppMap()
                state.rebuildOrderIndexMap()
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case .toggleEditMode:
                state.isEditMode.toggle()
                return .none

            case let .setEditMode(edit):
                // Idempotent set for Option-hold / long-press entry, which fire
                // on transitions rather than discrete taps. No-op when unchanged
                // so holding the key doesn't spam preference saves.
                guard state.isEditMode != edit else { return .none }
                state.isEditMode = edit
                return .none

            case let .setKeyboardSelectedID(id):
                state.keyboardSelectedID = id
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

            case let .moveAppBefore(id, before: targetID):
                // Edge-drop counterpart to moveApp(after:): dropping on an
                // icon's leading edge inserts before it (classic reorder).
                guard let fromIndex = state.orderIndexMap[id],
                      let toIndex = state.orderIndexMap[targetID],
                      id != targetID else {
                    return .none
                }

                var updatedOrder = state.appOrder
                updatedOrder.remove(at: fromIndex)
                let adjustedTarget = (fromIndex < toIndex) ? toIndex - 1 : toIndex
                updatedOrder.insert(id, at: adjustedTarget)

                if updatedOrder == state.appOrder {
                    return .none
                }

                state.appOrder = updatedOrder
                state.rebuildOrderIndexMap()
                state.updateDisplayedApps()
                return .send(.savePreferences)

            case let .moveFolderAfter(id, after: targetID):
                guard id != targetID,
                      let from = state.folders.firstIndex(where: { $0.id == id }),
                      let to = state.folders.firstIndex(where: { $0.id == targetID }) else {
                    return .none
                }
                var folders = state.folders
                let moving = folders.remove(at: from)
                let adjustedTarget = (from < to) ? to - 1 : to
                folders.insert(moving, at: adjustedTarget + 1)
                guard folders.map(\.id) != state.folders.map(\.id) else { return .none }
                state.folders = folders
                state.updateDisplayedApps()
                return .send(.savePreferences)

            case let .moveFolderBefore(id, before: targetID):
                guard id != targetID,
                      let from = state.folders.firstIndex(where: { $0.id == id }),
                      let to = state.folders.firstIndex(where: { $0.id == targetID }) else {
                    return .none
                }
                var folders = state.folders
                let moving = folders.remove(at: from)
                let adjustedTarget = (from < to) ? to - 1 : to
                folders.insert(moving, at: adjustedTarget)
                guard folders.map(\.id) != state.folders.map(\.id) else { return .none }
                state.folders = folders
                state.updateDisplayedApps()
                return .send(.savePreferences)

            case let .moveAppInFolderAfter(id, after: targetID, folderID):
                guard let idx = state.folders.firstIndex(where: { $0.id == folderID }),
                      id != targetID,
                      let from = state.folders[idx].appIDs.firstIndex(of: id),
                      let to = state.folders[idx].appIDs.firstIndex(of: targetID) else {
                    return .none
                }
                var appIDs = state.folders[idx].appIDs
                appIDs.remove(at: from)
                let adjustedTarget = (from < to) ? to - 1 : to
                appIDs.insert(id, at: adjustedTarget + 1)
                guard appIDs != state.folders[idx].appIDs else { return .none }
                state.folders[idx].appIDs = appIDs
                state.updateDisplayedApps()
                return .send(.savePreferences)

            case let .moveAppInFolderBefore(id, before: targetID, folderID):
                guard let idx = state.folders.firstIndex(where: { $0.id == folderID }),
                      id != targetID,
                      let from = state.folders[idx].appIDs.firstIndex(of: id),
                      let to = state.folders[idx].appIDs.firstIndex(of: targetID) else {
                    return .none
                }
                var appIDs = state.folders[idx].appIDs
                appIDs.remove(at: from)
                let adjustedTarget = (from < to) ? to - 1 : to
                appIDs.insert(id, at: adjustedTarget)
                guard appIDs != state.folders[idx].appIDs else { return .none }
                state.folders[idx].appIDs = appIDs
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .setSearchQuery(query):
                state.searchQuery = query
                state.keyboardSelectedID = nil
                state.updateDisplayedApps()
                return .none
                
            case let .openFolder(id):
                guard state.folders.contains(where: { $0.id == id }) else { return .none }
                if state.appMap.isEmpty && !state.apps.isEmpty {
                    state.rebuildAppMap()
                }
                state.openFolderID = id
                state.keyboardSelectedID = nil
                return .none

            case .closeFolder:
                state.openFolderID = nil
                state.keyboardSelectedID = nil
                return .none
                
            case let .createFolder(name, appIDs):
                let baseName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(256))
                guard !baseName.isEmpty else { return .none }

                // Only retain valid, unique app IDs and make folder membership exclusive.
                let availableIDs = Set(state.apps.map(\.id))
                var seenIDs = Set<UUID>()
                let validAppIDs = appIDs.filter {
                    availableIDs.contains($0) && seenIDs.insert($0).inserted
                }
                for idx in state.folders.indices {
                    state.folders[idx].appIDs.removeAll { seenIDs.contains($0) }
                }

                // Auto-uniquify names so repeated folder creation cannot collide.
                let finalName: String
                if state.folders.contains(where: { $0.name == baseName }) {
                    var counter = 2
                    var candidate = "\(baseName) \(counter)"
                    while state.folders.contains(where: { $0.name == candidate }) {
                        counter += 1
                        candidate = "\(baseName) \(counter)"
                    }
                    finalName = candidate
                } else {
                    finalName = baseName
                }
                state.folders.append(Folder(name: finalName, appIDs: validAppIDs))
                // Keep the newly created folder visible even when a previous search
                // query would otherwise filter it out.
                state.searchQuery = ""
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .renameFolder(id, name):
                let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(256))
                guard !trimmed.isEmpty,
                      let idx = state.folders.firstIndex(where: { $0.id == id }) else {
                    return .none
                }

                let finalName: String
                if state.folders.contains(where: { $0.name == trimmed && $0.id != id }) {
                    var counter = 2
                    var candidate = "\(trimmed) \(counter)"
                    while state.folders.contains(where: { $0.name == candidate && $0.id != id }) {
                        counter += 1
                        candidate = "\(trimmed) \(counter)"
                    }
                    finalName = candidate
                } else {
                    finalName = trimmed
                }
                guard state.folders[idx].name != finalName else { return .none }
                state.folders[idx].name = finalName
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .deleteFolder(id):
                let originalCount = state.folders.count
                state.folders.removeAll { $0.id == id }
                guard state.folders.count != originalCount else { return .none }
                state.updateDisplayedApps()
                if state.openFolderID == id {
                    state.openFolderID = nil
                }
                return .send(.savePreferences)
                
            case let .addAppToFolder(appID, folderID):
                guard state.apps.contains(where: { $0.id == appID }),
                      let targetIndex = state.folders.firstIndex(where: { $0.id == folderID }) else {
                    return .none
                }

                var changed = false
                for idx in state.folders.indices where idx != targetIndex {
                    let originalIDs = state.folders[idx].appIDs
                    state.folders[idx].appIDs.removeAll { $0 == appID }
                    changed = changed || originalIDs != state.folders[idx].appIDs
                }
                if !state.folders[targetIndex].appIDs.contains(appID) {
                    state.folders[targetIndex].appIDs.append(appID)
                    changed = true
                }
                guard changed else { return .none }
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .removeAppFromFolder(appID, folderID):
                guard let idx = state.folders.firstIndex(where: { $0.id == folderID }) else {
                    return .none
                }
                let originalIDs = state.folders[idx].appIDs
                state.folders[idx].appIDs.removeAll { $0 == appID }
                guard originalIDs != state.folders[idx].appIDs else { return .none }
                // Classic Launchpad drops a folder once its last app leaves;
                // lingering empty folders would otherwise accumulate.
                if state.folders[idx].appIDs.isEmpty {
                    state.folders.remove(at: idx)
                    if state.openFolderID == folderID {
                        state.openFolderID = nil
                    }
                }
                state.updateDisplayedApps()
                return .send(.savePreferences)
                
            case let .renameApp(bundleIdentifier, newName):
                guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
                let customName = String(newName.prefix(256))
                guard state.preferences.customAppNames[bundleIdentifier] != customName else { return .none }
                state.preferences.customAppNames[bundleIdentifier] = customName
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
                    Logger.appGrid.error("Preferences save failed: \(error, privacy: .public)")
                }
                .cancellable(id: "prefs-save", cancelInFlight: true)
                
            case .flushPendingSave:
                // Immediate flush — no debounce, no cancellation.
                // Called on app termination to ensure the last state is persisted.
                let prefs = UserPreferences(
                    appOrder: state.appOrder,
                    folders: state.folders,
                    showHiddenApps: state.preferences.showHiddenApps,
                    iconSize: state.preferences.iconSize,
                    columns: state.preferences.columns,
                    customAppNames: state.preferences.customAppNames
                )
                PreferencesStore.save(prefs)
                // Cancel any in-flight debounced save to prevent a stale write race,
                // plus any pending icon rescan (pointless once we're terminating).
                return .merge(
                    .cancel(id: "prefs-save"),
                    .cancel(id: "icon-rescan")
                )
                
            case .externalAppsChanged:
                // Fired by the /Applications directory observer (Fix 1): a silent
                // background rescan. The observer already invalidated the scan
                // cache, so this re-enumerates without forcing icon re-rasterize.
                // Must not clear a concurrent reload's spinner (clearsLoading: false).
                state.keyboardSelectedID = nil
                return .run { [
                    showHidden = state.preferences.showHiddenApps,
                    iconSize = state.preferences.iconSize
                ] send in
                    let apps = await AppScanner.shared.scanApps(
                        showHidden: showHidden,
                        iconSize: iconSize
                    )
                    await send(.appsLoaded(apps, clearsLoading: false))
                }

            case .reloadApps:
                state.isLoading = true
                return .run { [
                    showHidden = state.preferences.showHiddenApps,
                    iconSize = state.preferences.iconSize
                ] send in
                    let apps = await AppScanner.shared.scanApps(
                        showHidden: showHidden,
                        forceRefresh: true,
                        iconSize: iconSize
                    )
                    await send(.appsLoaded(apps))
                }
                
            case .refreshIconsAfterScreenChange:
                // Silent background refresh: no isLoading spinner. Non-forced,
                // so a display change that kept the same scale (AppScanner only
                // invalidates on scale change) is a cheap cache hit.
                return .run { [
                    showHidden = state.preferences.showHiddenApps,
                    iconSize = state.preferences.iconSize
                ] send in
                    let apps = await AppScanner.shared.scanApps(
                        showHidden: showHidden,
                        iconSize: iconSize
                    )
                    await send(.appsLoaded(apps, clearsLoading: false))
                }
                
            case .memoryPressureReceived:
                guard state.apps.contains(where: { $0.icon != nil }) else { return .none }
                for index in state.apps.indices {
                    state.apps[index].icon = nil
                }
                state.rebuildAppMap()
                state.updateDisplayedApps()
                return .none

            case .iconRescanDebounceFired:
                // Fired by RootFeature's debounced icon-size rescan. Reads state
                // fresh here (not captured across the debounce window) so a
                // showHidden toggle mid-debounce can't be overwritten with stale
                // results. Non-forced: a fresher scan that already covered this
                // size is a cheap cache hit instead of redundant work.
                return .run { [
                    showHidden = state.preferences.showHiddenApps,
                    iconSize = state.preferences.iconSize
                ] send in
                    let apps = await AppScanner.shared.scanApps(
                        showHidden: showHidden,
                        iconSize: iconSize
                    )
                    await send(.appsLoaded(apps, clearsLoading: false))
                }
            }
        }
    }
}
