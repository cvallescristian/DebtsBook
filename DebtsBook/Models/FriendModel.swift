import Foundation
import SwiftData

@Model
class Friend {
    var name: String
    var createdAt: Date
    
    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
