import Foundation

struct ChatMessage: Codable, Identifiable {
    var id: String
    var roundId: String
    var userId: String
    var userName: String
    var type: MessageType
    var text: String?
    var imageURL: String?
    var holeNumber: Int?
    var timestamp: Date
    
    var isScoreAlert: Bool {
        type == .scoreAlert
    }
}

enum MessageType: String, Codable {
    case text           // Regular chat message
    case photo          // Photo shared
    case scoreAlert     // Auto-generated: "Jerry scored 8 on Hole 3 💀"
    case reaction       // Emoji reaction to a score
    case roundEvent     // "Mike joined the round", "Round complete"
}

struct ScoreReaction: Codable, Identifiable {
    var id: String
    var scoreOwnerId: String
    var reactorId: String
    var reactorName: String
    var holeNumber: Int
    var emoji: String
    var timestamp: Date
}
