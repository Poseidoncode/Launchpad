import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var preferences: UserPreferences = PreferencesStore.load()
    }
    
    enum Action {
        case setIconSize(Double)
        case setColumns(Int)
        case setShowHiddenApps(Bool)
        case savePreferences
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setIconSize(size):
                state.preferences.iconSize = size
                return .send(.savePreferences)
            case let .setColumns(columns):
                state.preferences.columns = columns
                return .send(.savePreferences)
            case let .setShowHiddenApps(show):
                state.preferences.showHiddenApps = show
                return .send(.savePreferences)
            case .savePreferences:
                // Do NOT call PreferencesStore.save here — SettingsFeature's
                // preferences only has up-to-date values for iconSize, columns,
                // and showHiddenApps. The appOrder/folders/customAppNames fields
                // are stale (loaded at launch, never updated by AppGrid changes).
                // The RootFeature intercepts this action and routes the save
                // through AppGridFeature.savePreferences, which constructs
                // UserPreferences from the merged state (AppGrid's fields +
                // synced Settings fields) and writes the correct data to disk.
                return .none
            }
        }
    }
}
