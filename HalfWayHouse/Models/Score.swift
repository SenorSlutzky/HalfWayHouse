import Foundation

struct HoleScore: Codable, Identifiable {
    var id: Int { holeNumber }
    var holeNumber: Int
    var strokes: Int
    var putts: Int?
    var fairwayHit: Bool?
    var greenInRegulation: Bool?
    var timestamp: Date
}

struct PlayerRoundScore: Codable, Identifiable {
    var id: String { playerId }
    var playerId: String
    var playerName: String
    var scores: [HoleScore]
    var courseHandicap: Int?
    
    var grossTotal: Int {
        scores.reduce(0) { $0 + $1.strokes }
    }
    
    var netTotal: Int {
        grossTotal - (courseHandicap ?? 0)
    }
    
    var holesCompleted: Int {
        scores.count
    }
    
    var thruDisplay: String {
        if holesCompleted == 18 { return "F" }
        return "Thru \(holesCompleted)"
    }
    
    func scoreRelativeToPar(coursePar: [Int]) -> Int {
        var total = 0
        for score in scores {
            let holeIndex = score.holeNumber - 1
            guard holeIndex < coursePar.count else { continue }
            total += score.strokes - coursePar[holeIndex]
        }
        return total
    }
    
    func relativeToParDisplay(coursePar: [Int]) -> String {
        let relative = scoreRelativeToPar(coursePar: coursePar)
        if relative == 0 { return "E" }
        return relative > 0 ? "+\(relative)" : "\(relative)"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    var id: String { playerId }
    var playerId: String
    var playerName: String
    var position: Int
    var grossTotal: Int
    var netTotal: Int
    var relativeToPar: Int
    var holesCompleted: Int
    var lastUpdated: Date
    
    var positionDisplay: String {
        switch position {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(position)"
        }
    }
    
    var relativeToParDisplay: String {
        if relativeToPar == 0 { return "E" }
        return relativeToPar > 0 ? "+\(relativeToPar)" : "\(relativeToPar)"
    }
}
