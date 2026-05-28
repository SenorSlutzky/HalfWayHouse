import Foundation
import FirebaseDatabase

@MainActor
class RoundViewModel: ObservableObject {
    @Published var activeRound: Round?
    @Published var playerScores: [PlayerRoundScore] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var currentHole: Int = 1
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var scoresListener: DatabaseHandle?
    private var roundRef: DatabaseReference?
    
    deinit {
        stopListening()
    }
    
    // MARK: - Create Round
    
    func createRound(course: Course, format: ScoringFormat, games: [GameType], players: [String], createdBy: String) async -> String? {
        let roundId = UUID().uuidString
        let round = Round(
            id: roundId,
            courseId: course.id,
            courseName: course.name,
            groupId: nil,
            format: format,
            games: games,
            status: .active,
            players: players,
            createdBy: createdBy,
            createdAt: Date(),
            completedAt: nil
        )
        
        do {
            try await FirebaseService.shared.createRound(round)
            activeRound = round
            listenToScores(roundId: roundId)
            return roundId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Join Round
    
    func joinRound(roundId: String, userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            activeRound = try await FirebaseService.shared.getRound(roundId: roundId)
            listenToScores(roundId: roundId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Submit Score
    
    func submitScore(roundId: String, userId: String, userName: String, holeNumber: Int, strokes: Int, putts: Int? = nil) async {
        let holeScore = HoleScore(
            holeNumber: holeNumber,
            strokes: strokes,
            putts: putts,
            fairwayHit: nil,
            greenInRegulation: nil,
            timestamp: Date()
        )
        
        do {
            try await FirebaseService.shared.submitHoleScore(
                roundId: roundId,
                userId: userId,
                holeScore: holeScore
            )
            
            // Auto-advance to next hole
            if holeNumber < 18 {
                currentHole = holeNumber + 1
            }
            
            // Generate score alert for chat
            await generateScoreAlert(
                roundId: roundId,
                userId: userId,
                userName: userName,
                holeNumber: holeNumber,
                strokes: strokes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Real-time Listeners
    
    func listenToScores(roundId: String) {
        stopListening()
        
        let ref = Database.database().reference(withPath: "rounds/\(roundId)/scores")
        roundRef = ref
        
        scoresListener = ref.observe(.value) { [weak self] snapshot in
            guard let data = snapshot.value as? [String: Any] else { return }
            Task { @MainActor in
                self?.parseScores(data)
                self?.recalculateLeaderboard()
            }
        }
    }
    
    func stopListening() {
        if let listener = scoresListener, let ref = roundRef {
            ref.removeObserver(withHandle: listener)
        }
        scoresListener = nil
        roundRef = nil
    }
    
    // MARK: - Leaderboard Calculation
    
    private func parseScores(_ data: [String: Any]) {
        var scores: [PlayerRoundScore] = []
        
        for (userId, playerData) in data {
            guard let playerDict = playerData as? [String: Any] else { continue }
            let playerName = playerDict["playerName"] as? String ?? "Unknown"
            let handicap = playerDict["courseHandicap"] as? Int
            
            var holeScores: [HoleScore] = []
            if let holesData = playerDict["holes"] as? [String: Any] {
                for (holeKey, holeData) in holesData {
                    guard let holeDict = holeData as? [String: Any],
                          let holeNum = Int(holeKey.replacingOccurrences(of: "hole", with: "")),
                          let strokes = holeDict["strokes"] as? Int else { continue }
                    
                    let score = HoleScore(
                        holeNumber: holeNum,
                        strokes: strokes,
                        putts: holeDict["putts"] as? Int,
                        fairwayHit: holeDict["fairwayHit"] as? Bool,
                        greenInRegulation: holeDict["gir"] as? Bool,
                        timestamp: Date()
                    )
                    holeScores.append(score)
                }
            }
            
            holeScores.sort { $0.holeNumber < $1.holeNumber }
            
            scores.append(PlayerRoundScore(
                playerId: userId,
                playerName: playerName,
                scores: holeScores,
                courseHandicap: handicap
            ))
        }
        
        playerScores = scores
    }
    
    private func recalculateLeaderboard() {
        guard let round = activeRound else { return }
        
        var entries: [LeaderboardEntry] = playerScores.map { player in
            LeaderboardEntry(
                playerId: player.playerId,
                playerName: player.playerName,
                position: 0,
                grossTotal: player.grossTotal,
                netTotal: player.netTotal,
                relativeToPar: player.grossTotal, // Will be calculated with course par
                holesCompleted: player.holesCompleted,
                lastUpdated: Date()
            )
        }
        
        // Sort by net total (lower is better), then by holes completed (more is better for ties)
        entries.sort { a, b in
            if a.holesCompleted == 0 && b.holesCompleted > 0 { return false }
            if b.holesCompleted == 0 && a.holesCompleted > 0 { return true }
            if a.netTotal == b.netTotal {
                return a.holesCompleted > b.holesCompleted
            }
            return a.netTotal < b.netTotal
        }
        
        // Assign positions
        for (index, _) in entries.enumerated() {
            entries[index].position = index + 1
        }
        
        leaderboard = entries
    }
    
    // MARK: - Score Alerts
    
    private func generateScoreAlert(roundId: String, userId: String, userName: String, holeNumber: Int, strokes: Int) async {
        // Get course par for the hole to generate appropriate alert
        guard let round = activeRound else { return }
        let course = await FirebaseService.shared.getCourse(courseId: round.courseId)
        guard let course = course, holeNumber <= course.holes.count else { return }
        
        let par = course.holes[holeNumber - 1].par
        let diff = strokes - par
        
        let alertText: String
        switch diff {
        case ...(-2): alertText = "🦅 \(userName) just EAGLED Hole \(holeNumber)!"
        case -1: alertText = "🐦 \(userName) birdied Hole \(holeNumber)!"
        case 0: return // Don't alert for par
        case 1: alertText = "\(userName) bogeyed Hole \(holeNumber)"
        case 2: alertText = "😬 \(userName) doubled Hole \(holeNumber)"
        case 3...: alertText = "💀 \(userName) made \(strokes) on the par \(par) Hole \(holeNumber)..."
        default: return
        }
        
        let alert = ChatMessage(
            id: UUID().uuidString,
            roundId: roundId,
            userId: "system",
            userName: "Half Way House",
            type: .scoreAlert,
            text: alertText,
            imageURL: nil,
            holeNumber: holeNumber,
            timestamp: Date()
        )
        
        await FirebaseService.shared.sendChatMessage(alert)
    }
    
    // MARK: - Complete Round
    
    func completeRound(roundId: String) async {
        do {
            try await FirebaseService.shared.updateRoundStatus(roundId: roundId, status: .completed)
            activeRound?.status = .completed
            stopListening()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
