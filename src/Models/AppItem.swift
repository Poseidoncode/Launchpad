import Foundation
import AppKit
import CryptoKit

struct AppItem: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var bundleIdentifier: String
    var path: URL
    var icon: NSImage?
    var isFolder: Bool
    var folderID: UUID?
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        path: URL,
        icon: NSImage? = nil,
        isFolder: Bool = false,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
        self.isFolder = isFolder
        self.folderID = folderID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, bundleIdentifier, path, isFolder, folderID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        path = try container.decode(URL.self, forKey: .path)
        isFolder = try container.decode(Bool.self, forKey: .isFolder)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        icon = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(path, forKey: .path)
        try container.encode(isFolder, forKey: .isFolder)
        try container.encodeIfPresent(folderID, forKey: .folderID)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
    
    static func stableID(bundleIdentifier: String, path: URL) -> UUID {
        let source = "\(bundleIdentifier)\n\(path.path)"
        let digest = SHA256.hash(data: Data(source.utf8))
        let bytes = Array(digest.prefix(16))
        
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
