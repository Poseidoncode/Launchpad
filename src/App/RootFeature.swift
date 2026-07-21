import ComposableArchitecture
import Foundation

/// Root reducer that owns both AppGrid and Settings state in a single Store.
/// Eliminates the NotificationCenter-based coupling between two independent stores.
@Reducer
struct RootFeature {
    @ObservableState
    struct State: Equatable {
        var appGrid = AppGridFeature.State()
        var settings = SettingsFeature.State()
    }

    enum Action {
        case appGrid(AppGridFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.appGrid, action: \.appGrid) {
            AppGridFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        // Cross-feature: when Settings saves, sync only the fields Settings
        // manages (iconSize, columns, showHiddenApps) into AppGrid's state,
        // then route the save through AppGridFeature.savePreferences which
        // constructs UserPreferences from the merged state and writes the
        // correct data to disk (preserving AppGrid's appOrder/folders/customAppNames).
        Reduce { state, action in
            switch action {
            case .settings(.savePreferences):
                let oldShowHidden = state.appGrid.preferences.showHiddenApps
                let oldIconSize = state.appGrid.preferences.iconSize
                // Sync only Settings-managed fields into AppGrid's preferences
                state.appGrid.preferences.iconSize = state.settings.preferences.iconSize
                state.appGrid.preferences.columns = state.settings.preferences.columns
                state.appGrid.preferences.showHiddenApps = state.settings.preferences.showHiddenApps
                state.appGrid.updateDisplayedApps()
                // Save merged preferences via AppGrid's debounced save.
                // Rescan when showHiddenApps changes, or when iconSize grows enough
                // that the raster point footprint (incl. hover) would increase.
                let iconSizeIncreased = UserPreferences.iconSizeRequiresHigherResolution(
                    from: oldIconSize,
                    to: state.appGrid.preferences.iconSize
                )
                if oldShowHidden != state.appGrid.preferences.showHiddenApps || iconSizeIncreased {
                    return .merge(
                        .send(.appGrid(.savePreferences)),
                        .run { [
                            showHidden = state.appGrid.preferences.showHiddenApps,
                            iconSize = state.appGrid.preferences.iconSize,
                            iconSizeIncreased
                        ] send in
                            if iconSizeIncreased {
                                await IconCache.shared.clear()
                            }
                            // Pass iconSize from state — PreferencesStore may still hold
                            // the old value until the debounced savePreferences writes.
                            await send(.appGrid(.appsLoaded(
                                await AppScanner.shared.scanApps(
                                    showHidden: showHidden,
                                    forceRefresh: iconSizeIncreased,
                                    iconSize: iconSize
                                )
                            )))
                        }
                    )
                }
                return .send(.appGrid(.savePreferences))

            default:
                return .none
            }
        }
    }
}
