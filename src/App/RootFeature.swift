import ComposableArchitecture
import Foundation
import OSLog

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
                // No updateDisplayedApps: displayedApps depends only on
                // apps/search/folders/order/custom names, none of which Settings
                // changes. Layout reads preferences directly, and a rescan's
                // appsLoaded recomputes anyway.
                // Save merged preferences via AppGrid's debounced save.
                // Rescan when showHiddenApps changes, or when iconSize grows enough
                // that the raster point footprint (incl. hover) would increase.
                // Never IconCache.clear() here: entries are keyed by size, so a
                // stale size simply misses — and hits again if the user shrinks
                // back, instead of forcing a full re-rasterize.
                let iconSizeIncreased = UserPreferences.iconSizeRequiresHigherResolution(
                    from: oldIconSize,
                    to: state.appGrid.preferences.iconSize
                )
                if oldShowHidden != state.appGrid.preferences.showHiddenApps {
                    // The immediate scan below captures the latest state (including
                    // the latest icon size), so it supersedes any pending icon-size
                    // debounce — cancel the timer to avoid one redundant wake-up.
                    return .merge(
                        .send(.appGrid(.savePreferences)),
                        .cancel(id: "icon-rescan"),
                        .run { [
                            showHidden = state.appGrid.preferences.showHiddenApps,
                            iconSize = state.appGrid.preferences.iconSize,
                            iconSizeIncreased
                        ] send in
                            // Pass iconSize from state — PreferencesStore may still hold
                            // the old value until the debounced savePreferences writes.
                            // Background scan (no spinner was shown): must not clear a
                            // concurrent reload's isLoading.
                            await send(.appGrid(.appsLoaded(
                                await AppScanner.shared.scanApps(
                                    showHidden: showHidden,
                                    forceRefresh: iconSizeIncreased,
                                    iconSize: iconSize
                                ),
                                clearsLoading: false
                            )))
                        }
                    )
                }
                if iconSizeIncreased {
                    // Debounced: the icon-size slider fires continuously while
                    // dragging. Layout updates live from preferences; one rescan
                    // after the drag settles attaches full-resolution bitmaps.
                    // Only the timer is debounced — the fired action reads fresh
                    // state, so settings changed mid-debounce can't go stale.
                    return .merge(
                        .send(.appGrid(.savePreferences)),
                        .run { send in
                            try await Task.sleep(nanoseconds: 350_000_000)
                            await send(.appGrid(.iconRescanDebounceFired))
                        } catch: { error, _ in
                            if error is CancellationError { return }
                            Logger.appGrid.error("Icon rescan debounce failed: \(error, privacy: .public)")
                        }
                        .cancellable(id: "icon-rescan", cancelInFlight: true)
                    )
                }
                // NOTE: no .cancel(id: "icon-rescan") here. A pending debounce
                // always fires with fresh state: if the size is still grown it
                // performs the rescan the grid needs for sharp icons, otherwise
                // it is a cheap cache hit. Cancelling on shrink would leave
                // grow-then-partially-shrink sequences with soft bitmaps.
                return .send(.appGrid(.savePreferences))

            default:
                return .none
            }
        }
    }
}
