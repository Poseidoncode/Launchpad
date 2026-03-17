import Foundation
import AppKit
import CoreServices

actor FileSearcher {
    static let shared = FileSearcher()
    
    func search(query: String) async -> [AppItem] {
        guard !query.isEmpty else { return [] }
        
        let searchScope = ["/Applications", "/System/Applications",
                           NSHomeDirectory() + "/Applications"]
        
        let queryString = "kMDItemKind == 'Application' && kMDItemDisplayName == '*\(query)*'cdw"
        guard let mdQuery = MDQueryCreate(kCFAllocatorDefault, queryString as CFString, nil, nil) else {
            return []
        }
        
        MDQuerySetSearchScope(mdQuery, searchScope as CFArray, 0)
        MDQueryExecute(mdQuery, CFOptionFlags(kMDQuerySynchronous.rawValue))
        
        var results: [AppItem] = []
        let count = MDQueryGetResultCount(mdQuery)
        
        for i in 0..<count {
            guard let item = MDQueryGetResultAtIndex(mdQuery, i) else { continue }
            let mdItem = item as! MDItem
            if let pathStr = MDItemCopyAttribute(mdItem, kMDItemPath) as? String {
                let url = URL(fileURLWithPath: pathStr)
                let bundle = Bundle(url: url)
                let name = MDItemCopyAttribute(mdItem, kMDItemDisplayName) as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let bundleID = bundle?.bundleIdentifier ?? pathStr
                let icon = NSWorkspace.shared.icon(forFile: pathStr)
                results.append(AppItem(name: name, bundleIdentifier: bundleID, path: url, icon: icon))
            }
        }
        
        return results
    }
}