import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var leaderboardVM = LeaderboardViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if leaderboardVM.liveRounds.isEmpty {
                        emptyState
                    } else {
                        ForEach(leaderboardVM.liveRounds) { round in
                            roundLeaderboardCard(round: round)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Leaderboard")
            .task {
                if let userId = authViewModel.currentUser?.id {
                    await leaderboardVM.fetchActiveRounds(for: userId)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.5))
            
            Text("No Live Rounds")
                .font(.title3.bold())
            
            Text("Start a round or wait for your friends to tee off. You'll see live leaderboards here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Round Leaderboard Card
    
    private func roundLeaderboardCard(round: Round) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(round.courseName)
                        .font(.headline)
                    Text(round.format.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            // Column Headers
            HStack {
                Text("POS")
                    .frame(width: 36, alignment: .leading)
                Text("PLAYER")
                Spacer()
                Text("THRU")
                    .frame(width: 50)
                Text("NET")
                    .frame(width: 40)
                Text("TO PAR")
                    .frame(width: 50)
            }
            .font(.caption2.bold())
            .foregroundColor(.secondary)
            
            // Entries
            let entries = leaderboardVM.friendsLeaderboards[round.id] ?? []
            ForEach(entries) { entry in
                leaderboardRow(entry: entry)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Leaderboard Row
    
    private func leaderboardRow(entry: LeaderboardEntry) -> some View {
        HStack {
            Text(entry.positionDisplay)
                .frame(width: 36, alignment: .leading)
                .font(.subheadline)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(entry.playerName.prefix(1)))
                            .font(.caption.bold())
                    )
                
                Text(entry.playerName)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(entry.holesCompleted == 18 ? "F" : "\(entry.holesCompleted)")
                .frame(width: 50)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(entry.netTotal)")
                .frame(width: 40)
                .font(.subheadline.bold())
            
            Text(entry.relativeToParDisplay)
                .frame(width: 50)
                .font(.subheadline.bold())
                .foregroundColor(entry.relativeToPar < 0 ? .red : entry.relativeToPar == 0 ? .primary : .blue)
        }
        .padding(.vertical, 4)
    }
}
