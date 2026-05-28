import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var leaderboardVM = LeaderboardViewModel()
    @State private var showNewRound = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    headerSection
                    
                    // Quick Start Button
                    startRoundButton
                    
                    // Active Rounds (Friends Playing Now)
                    if !leaderboardVM.liveRounds.isEmpty {
                        activeRoundsSection
                    }
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Half Way House")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { }) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $showNewRound) {
                StartRoundView()
            }
            .task {
                if let userId = authViewModel.currentUser?.id {
                    await leaderboardVM.fetchActiveRounds(for: userId)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hey \(authViewModel.currentUser?.displayName.components(separatedBy: " ").first ?? "Golfer") 👋")
                    .font(.title2.bold())
                
                Text("Your boys are watching.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Start Round Button
    
    private var startRoundButton: some View {
        Button(action: { showNewRound = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Start a Round")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
    }
    
    // MARK: - Active Rounds
    
    private var activeRoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "livephoto")
                    .foregroundColor(.red)
                Text("LIVE NOW")
                    .font(.caption.bold())
                    .foregroundColor(.red)
                Spacer()
            }
            
            ForEach(leaderboardVM.liveRounds) { round in
                NavigationLink(destination: LiveRoundView(round: round)) {
                    LiveRoundCard(round: round, leaderboard: leaderboardVM.friendsLeaderboards[round.id] ?? [])
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
            
            // Placeholder for recent rounds
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 80)
                .overlay(
                    Text("No recent rounds yet. Start one!")
                        .foregroundColor(.secondary)
                )
        }
    }
}

// MARK: - Live Round Card

struct LiveRoundCard: View {
    let round: Round
    let leaderboard: [LeaderboardEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(round.courseName)
                    .font(.subheadline.bold())
                Spacer()
                Text("LIVE")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            // Mini leaderboard
            ForEach(leaderboard.prefix(4)) { entry in
                HStack {
                    Text(entry.positionDisplay)
                        .frame(width: 24)
                    Text(entry.playerName)
                        .font(.caption)
                    Spacer()
                    Text(entry.relativeToParDisplay)
                        .font(.caption.bold())
                        .foregroundColor(entry.relativeToPar <= 0 ? .red : .primary)
                    Text(entry.holesCompleted == 18 ? "F" : "Thru \(entry.holesCompleted)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Views

struct LiveRoundView: View {
    let round: Round
    var body: some View {
        Text("Live Round: \(round.courseName)")
            .navigationTitle(round.courseName)
    }
}
