import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<AppGridFeature>
    @State private var showFolders: Bool = false
    
    var body: some View {
        ZStack {
            AppGridView(store: store)
            
            if showFolders {
                // FolderView overlay
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: { showFolders.toggle() }) {
                    Image(systemName: "folder")
                }
            }
        }
        .sheet(isPresented: $showFolders) {
            FolderView(
                store: Store(initialState: FolderFeature.State(folders: store.folders)) {
                    FolderFeature()
                }
            )
        }
    }
}