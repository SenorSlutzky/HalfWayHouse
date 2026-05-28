import Foundation
import FirebaseDatabase

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var liveRounds: [Round] = []
    @Published var friendsLeaderboards: [String: [LeaderboardEntry]] = [:]
    @Published var isLoading = false
    
    private var listeners: [DatabaseHandle] = []
    private var refs: [DatabaseReference] = []
    
    deinit {
        stopAllListeners()
    }
    
    // MARK: - Fetch Active Rounds for Friends
    
    func fetchActiveRounds(for userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        let rounds = await FirebaseService.shared.getActiveRoundsForUser(userId: userId)
        liveRounds = rounds
        
        // Listen to each active round's leaderboard
        for round in rounds {
            listenToRoundLeaderboard(roundId: round.id)
        }
    }
    
    // MARK: - Listen to a Round's Leaderboard
    
    private func listenToRoundLeaderboard(roundId: String) {
        let ref = Database.database().reference(withPath: "rounds/\(roundId)/leaderboard")
        refs.append(ref)
        
        let handle = ref.observe(.value) { [weak self] snapshot in
            guard let data = snapshot.value as? [[String: Any]] else { return }
            
            let entries = data.compactMap { dict -> LeaderboardEntry? in
                guard let playerId = dict["playerId"] as? String,
                      let playerName = dict["playerName"] as? String,
                      let position = dict["position"] as? Int,
                      let gross = dict["grossTotal"] as? Int else { return nil }
                
                return LeaderboardEntry(
                    playerId: playerId,
                    playerName: playerName,
                    position: position,
                    grossTotal: gross,
                    netTotal: dict["netTotal"] as? Int ?? gross,
                    relativeToPar: dict["relativeToPar"] as? Int ?? 0,
                    holesCompleted: dict["holesCompleted"] as? Int ?? 0,
                    lastUpdated: Date()
                )
            }
            
            Task { @MainActor in
                self?.friendsLeaderboards[roundId] = entries
            }
        }
        
        listeners.append(handle)
    }
    
    func stopAllListeners() {
        for (index, handle) in listeners.enumerated() {
            if index < refs.count {
                refs[index].removeObserver(withHandle: handle)
            }
        }
        listeners.removeAll()
        refs.removeAll()
    }
}
