import SwiftUI
import Foundation

struct AppDropDelegate: DropDelegate {
    let onDrop: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: ["public.file-url"])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: ["public.file-url"])
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                DispatchQueue.main.async {
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        onDrop(url)
                    }
                }
            }
        }
        return true
    }
}