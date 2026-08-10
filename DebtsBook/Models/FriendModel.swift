import Foundation
import SwiftData

@Model
class Friend {
    var name: String = ""
    var createdAt: Date = Date()
    var remoteID: UUID?
    var linkedUserID: UUID?
    var connectionID: UUID?

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
