import Foundation

struct Round: Codable, Identifiable {
    var id: String
    var courseId: String
    var courseName: String
    var groupId: String?
    var format: ScoringFormat
    var games: [GameType]
    var status: RoundStatus
    var players: [String] // user IDs
    var createdBy: String
    var createdAt: Date
    var completedAt: Date?
    
    var isActive: Bool {
        status == .active
    }
}

enum RoundStatus: String, Codable {
    case pending    // Created, waiting for players to join
    case active     // In progress
    case completed  // All players finished
    case cancelled
}

enum ScoringFormat: String, Codable, CaseIterable {
    case strokePlay = "Stroke Play"
    case matchPlay = "Match Play"
    case stableford = "Stableford"
    
    var description: String { rawValue }
    
    var icon: String {
        switch self {
        case .strokePlay: return "number"
        case .matchPlay: return "person.2"
        case .stableford: return "star.fill"
        }
    }
}

enum GameType: String, Codable, CaseIterable {
    case skins = "Skins"
    case nassau = "Nassau"
    case matchPlay = "Match Play"
    case wolf = "Wolf"
    case stableford = "Stableford"
    
    var description: String { rawValue }
    
    var icon: String {
        switch self {
        case .skins: return "dollarsign.circle"
        case .nassau: return "flag.2.crossed"
        case .matchPlay: return "person.2"
        case .wolf: return "pawprint"
        case .stableford: return "star"
        }
    }
}
