import Foundation
import FirebaseDatabase

struct HWHUser: Codable, Identifiable {
    var id: String
    var displayName: String
    var email: String
    var handicap: Double?
    var homeCourse: String?
    var avatarURL: String?
    var friends: [String]
    var createdAt: Date
    
    var handicapDisplay: String {
        guard let hcp = handicap else { return "N/A" }
        return String(format: "%.1f", hcp)
    }
}

struct UserStats: Codable {
    var roundsPlayed: Int
    var averageScore: Double?
    var bestRound: Int?
    var totalBirdies: Int
    var totalEagles: Int
    var skinsWon: Int
    var matchesWon: Int
    var matchesLost: Int
}
