import ComposableArchitecture
import Foundation
import AppKit

@Reducer
struct SearchFeature {
    @ObservableState
    struct State: Equatable {
        var query: String = ""
        var results: [AppItem] = []
        var isSearching: Bool = false
    }
    
    enum Action {
        case setQuery(String)
        case searchResults([AppItem])
        case clearSearch
        case launchApp(AppItem)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setQuery(query):
                state.query = query
                guard !query.isEmpty else {
                    state.results = []
                    return .none
                }
                state.isSearching = true
                return .run { send in
                    let results = await FileSearcher.shared.search(query: query)
                    await send(.searchResults(results))
                }
            case let .searchResults(results):
                state.isSearching = false
                state.results = results
                return .none
            case .clearSearch:
                state.query = ""
                state.results = []
                return .none
            case let .launchApp(app):
                NSWorkspace.shared.open(app.path)
                return .none
            }
        }
    }
}