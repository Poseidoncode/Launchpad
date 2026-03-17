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
                PreferencesStore.save(state.preferences)
                return .none
            }
        }
    }
}