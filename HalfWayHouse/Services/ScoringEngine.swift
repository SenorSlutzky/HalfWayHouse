import Foundation

/// Scoring engine that handles all game format calculations.
/// Inspired by 18 Birdies auto-tracking — players just enter strokes,
/// the engine handles all game math automatically.
class ScoringEngine {
    
    // MARK: - Stroke Play
    
    struct StrokePlayResult {
        var playerId: String
        var playerName: String
        var grossTotal: Int
        var netTotal: Int
        var relativeToPar: Int
        var position: Int
    }
    
    static func calculateStrokePlay(
        players: [PlayerRoundScore],
        coursePar: [Int],
        useNet: Bool = true
    ) -> [StrokePlayResult] {
        var results = players.map { player in
            let grossTotal = player.grossTotal
            let netTotal = useNet ? player.netTotal : grossTotal
            let parForHolesPlayed = player.scores.reduce(0) { sum, score in
                let holeIndex = score.holeNumber - 1
                guard holeIndex < coursePar.count else { return sum }
                return sum + coursePar[holeIndex]
            }
            let relativeToPar = grossTotal - parForHolesPlayed
            
            return StrokePlayResult(
                playerId: player.playerId,
                playerName: player.playerName,
                grossTotal: grossTotal,
                netTotal: netTotal,
                relativeToPar: relativeToPar,
                position: 0
            )
        }
        
        // Sort by net total (or gross if not using net)
        results.sort { useNet ? $0.netTotal < $1.netTotal : $0.grossTotal < $1.grossTotal }
        
        for i in results.indices {
            results[i].position = i + 1
        }
        
        return results
    }
    
    // MARK: - Skins
    
    struct SkinResult {
        var holeNumber: Int
        var winnerId: String?
        var winnerName: String?
        var pushed: Bool // true if hole was tied (skin carries over)
    }
    
    struct SkinsGameResult {
        var results: [SkinResult]
        var skinsByPlayer: [String: Int] // playerId -> number of skins won
        var carryOvers: Int // current number of accumulated carry-overs
    }
    
    static func calculateSkins(
        players: [PlayerRoundScore],
        throughHole: Int,
        useNet: Bool = false,
        coursePar: [Int]? = nil,
        handicapStrokes: [String: [Int]]? = nil // playerId -> holes where they get a stroke
    ) -> SkinsGameResult {
        var results: [SkinResult] = []
        var skinsByPlayer: [String: Int] = [:]
        var carryOvers = 0
        
        for holeNum in 1...throughHole {
            // Get each player's score for this hole
            var holeScores: [(playerId: String, name: String, score: Int)] = []
            
            for player in players {
                guard let holeScore = player.scores.first(where: { $0.holeNumber == holeNum }) else {
                    continue
                }
                
                var adjustedScore = holeScore.strokes
                
                // Apply handicap strokes if using net
                if useNet, let strokes = handicapStrokes?[player.playerId],
                   strokes.contains(holeNum) {
                    adjustedScore -= 1
                }
                
                holeScores.append((player.playerId, player.playerName, adjustedScore))
            }
            
            // Need at least 2 players to have scored this hole
            guard holeScores.count >= 2 else {
                results.append(SkinResult(holeNumber: holeNum, winnerId: nil, winnerName: nil, pushed: true))
                carryOvers += 1
                continue
            }
            
            // Find lowest score
            let minScore = holeScores.min(by: { $0.score < $1.score })!.score
            let winners = holeScores.filter { $0.score == minScore }
            
            if winners.count == 1 {
                // Clear winner — gets this skin + any carry-overs
                let winner = winners[0]
                let skinsWon = 1 + carryOvers
                skinsByPlayer[winner.playerId, default: 0] += skinsWon
                results.append(SkinResult(holeNumber: holeNum, winnerId: winner.playerId, winnerName: winner.name, pushed: false))
                carryOvers = 0
            } else {
                // Tie — skin carries over
                results.append(SkinResult(holeNumber: holeNum, winnerId: nil, winnerName: nil, pushed: true))
                carryOvers += 1
            }
        }
        
        return SkinsGameResult(results: results, skinsByPlayer: skinsByPlayer, carryOvers: carryOvers)
    }
    
    // MARK: - Match Play
    
    struct MatchPlayResult {
        var player1Id: String
        var player2Id: String
        var player1Name: String
        var player2Name: String
        var player1Up: Int // positive = player1 is up, negative = player2 is up
        var holesPlayed: Int
        var holesRemaining: Int
        var status: MatchStatus
        
        var displayText: String {
            if status == .tied { return "All Square" }
            let leader = player1Up > 0 ? player1Name : player2Name
            let margin = abs(player1Up)
            if status == .complete {
                return "\(leader) wins \(margin)&\(holesRemaining)"
            }
            return "\(leader) \(margin) UP"
        }
    }
    
    enum MatchStatus {
        case inProgress
        case complete
        case tied
    }
    
    static func calculateMatchPlay(
        player1: PlayerRoundScore,
        player2: PlayerRoundScore,
        totalHoles: Int = 18,
        useNet: Bool = false,
        handicapStrokes1: [Int] = [], // holes where player1 gets a stroke
        handicapStrokes2: [Int] = []  // holes where player2 gets a stroke
    ) -> MatchPlayResult {
        var player1Up = 0
        var holesPlayed = 0
        
        let maxHole = min(
            player1.scores.max(by: { $0.holeNumber < $1.holeNumber })?.holeNumber ?? 0,
            player2.scores.max(by: { $0.holeNumber < $1.holeNumber })?.holeNumber ?? 0
        )
        
        for holeNum in 1...max(1, maxHole) {
            guard let score1 = player1.scores.first(where: { $0.holeNumber == holeNum }),
                  let score2 = player2.scores.first(where: { $0.holeNumber == holeNum }) else {
                continue
            }
            
            var adj1 = score1.strokes
            var adj2 = score2.strokes
            
            if useNet {
                if handicapStrokes1.contains(holeNum) { adj1 -= 1 }
                if handicapStrokes2.contains(holeNum) { adj2 -= 1 }
            }
            
            if adj1 < adj2 {
                player1Up += 1
            } else if adj2 < adj1 {
                player1Up -= 1
            }
            
            holesPlayed += 1
        }
        
        let holesRemaining = totalHoles - holesPlayed
        
        // Check if match is over (lead > holes remaining)
        let status: MatchStatus
        if abs(player1Up) > holesRemaining {
            status = .complete
        } else if holesRemaining == 0 && player1Up == 0 {
            status = .tied
        } else if holesRemaining == 0 {
            status = .complete
        } else {
            status = .inProgress
        }
        
        return MatchPlayResult(
            player1Id: player1.playerId,
            player2Id: player2.playerId,
            player1Name: player1.playerName,
            player2Name: player2.playerName,
            player1Up: player1Up,
            holesPlayed: holesPlayed,
            holesRemaining: holesRemaining,
            status: status
        )
    }
    
    // MARK: - Nassau
    
    struct NassauResult {
        var frontNine: MatchPlayResult
        var backNine: MatchPlayResult
        var overall: MatchPlayResult
    }
    
    static func calculateNassau(
        player1: PlayerRoundScore,
        player2: PlayerRoundScore,
        useNet: Bool = false,
        handicapStrokes1: [Int] = [],
        handicapStrokes2: [Int] = []
    ) -> NassauResult {
        // Split scores into front 9 and back 9
        let p1Front = PlayerRoundScore(
            playerId: player1.playerId,
            playerName: player1.playerName,
            scores: player1.scores.filter { $0.holeNumber <= 9 },
            courseHandicap: player1.courseHandicap
        )
        let p2Front = PlayerRoundScore(
            playerId: player2.playerId,
            playerName: player2.playerName,
            scores: player2.scores.filter { $0.holeNumber <= 9 },
            courseHandicap: player2.courseHandicap
        )
        let p1Back = PlayerRoundScore(
            playerId: player1.playerId,
            playerName: player1.playerName,
            scores: player1.scores.filter { $0.holeNumber > 9 },
            courseHandicap: player1.courseHandicap
        )
        let p2Back = PlayerRoundScore(
            playerId: player2.playerId,
            playerName: player2.playerName,
            scores: player2.scores.filter { $0.holeNumber > 9 },
            courseHandicap: player2.courseHandicap
        )
        
        let front = calculateMatchPlay(player1: p1Front, player2: p2Front, totalHoles: 9, useNet: useNet, handicapStrokes1: handicapStrokes1.filter { $0 <= 9 }, handicapStrokes2: handicapStrokes2.filter { $0 <= 9 })
        let back = calculateMatchPlay(player1: p1Back, player2: p2Back, totalHoles: 9, useNet: useNet, handicapStrokes1: handicapStrokes1.filter { $0 > 9 }, handicapStrokes2: handicapStrokes2.filter { $0 > 9 })
        let overall = calculateMatchPlay(player1: player1, player2: player2, totalHoles: 18, useNet: useNet, handicapStrokes1: handicapStrokes1, handicapStrokes2: handicapStrokes2)
        
        return NassauResult(frontNine: front, backNine: back, overall: overall)
    }
    
    // MARK: - Handicap Stroke Allocation
    
    /// Determines which holes a player receives handicap strokes on,
    /// based on their course handicap and the hole handicap indices.
    static func allocateHandicapStrokes(
        courseHandicap: Int,
        holes: [HoleInfo]
    ) -> [Int] {
        // Sort holes by handicap index (hardest first)
        let sortedByDifficulty = holes.sorted { $0.handicapIndex < $1.handicapIndex }
        
        // Player gets strokes on the hardest holes first
        let strokeHoles = sortedByDifficulty.prefix(min(courseHandicap, 18))
        return strokeHoles.map { $0.number }
    }
    
    /// Calculate course handicap from player handicap index
    static func courseHandicap(handicapIndex: Double, slopeRating: Int, courseRating: Double, par: Int) -> Int {
        // Formula: Course Handicap = Handicap Index × (Slope Rating ÷ 113) + (Course Rating - Par)
        let raw = handicapIndex * (Double(slopeRating) / 113.0) + (courseRating - Double(par))
        return Int(raw.rounded())
    }
}
