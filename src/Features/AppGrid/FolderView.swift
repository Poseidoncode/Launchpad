import SwiftUI
import ComposableArchitecture

struct FolderView: View {
    @Bindable var store: StoreOf<FolderFeature>
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let folder = store.currentFolder {
                // Folder detail view
                folderDetailContent(folder: folder)
            } else {
                // Folder list
                folderListContent
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
    
    @ViewBuilder
    private var folderListContent: some View {
        Text("Folders")
            .font(.headline)
            .padding()
        
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(store.folders) { folder in
                folderItem(folder: folder)
                    .contextMenu {
                        Button("Open") { store.send(.selectFolder(folder.id.uuidString)) }
                        Divider()
                        Button("Delete", role: .destructive) { /* handled upstream */ }
                    }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    @ViewBuilder
    private func folderDetailContent(folder: Folder) -> some View {
        HStack {
            Button(action: { store.send(.close) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            
            Text(folder.name)
                .font(.headline)
            
            Spacer()
        }
        .padding()
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 16) {
            ForEach(store.folders.first(where: { $0.id == folder.id })?.appIDs ?? [], id: \.self) { appID in
                // App items inside folder (icons rendered by parent)
                VStack(spacing: 4) {
                    Image(systemName: "app.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.secondary)
                    Text(appID.uuidString.prefix(8))
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .frame(width: 72)
                .contextMenu {
                    Button("Remove from Folder") {
                        store.send(.removeApp(folderId: folder.id.uuidString, appId: appID.uuidString))
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func folderItem(folder: Folder) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .foregroundStyle(.blue)
            
            Text(folder.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .frame(width: 80)
        .onTapGesture { store.send(.selectFolder(folder.id.uuidString)) }
    }
}