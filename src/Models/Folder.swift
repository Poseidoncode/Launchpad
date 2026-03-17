import Foundation

struct Folder: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var appIDs: [UUID]
    
    init(id: UUID = UUID(), name: String, appIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.appIDs = appIDs
    }
}