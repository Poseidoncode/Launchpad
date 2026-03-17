import Foundation
import AppKit

actor AppScanner {
    static let shared = AppScanner()
    
    private let searchPaths: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities")
    ]
    
    func scanApps() async -> [AppItem] {
        var apps: [AppItem] = []
        let fileManager = FileManager.default
        
        for path in searchPaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for url in contents where url.pathExtension == "app" {
                if let app = makeAppItem(from: url) {
                    apps.append(app)
                }
            }
        }
        
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private func makeAppItem(from url: URL) -> AppItem? {
        let bundle = Bundle(url: url)
        let name = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? url.path
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        
        return AppItem(
            name: name,
            bundleIdentifier: bundleID,
            path: url,
            icon: icon
        )
    }
}