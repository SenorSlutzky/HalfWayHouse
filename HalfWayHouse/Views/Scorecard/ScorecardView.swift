import SwiftUI

struct ScorecardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var roundVM = RoundViewModel()
    @State private var selectedHole: Int = 1
    @State private var strokeCount: Int = 4
    @State private var puttCount: Int = 2
    @State private var showChat = false
    
    let roundId: String
    let course: Course
    
    var body: some View {
        VStack(spacing: 0) {
            // Top: Mini Leaderboard
            miniLeaderboard
            
            Divider()
            
            // Middle: Hole Selector
            holeSelector
            
            // Main: Score Entry
            scoreEntryArea
            
            Divider()
            
            // Bottom: Action Bar
            actionBar
        }
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showChat = true }) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .sheet(isPresented: $showChat) {
            RoundChatView(roundId: roundId)
        }
        .onAppear {
            roundVM.listenToScores(roundId: roundId)
        }
        .onDisappear {
            roundVM.stopListening()
        }
    }
    
    // MARK: - Mini Leaderboard
    
    private var miniLeaderboard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(roundVM.leaderboard) { entry in
                    VStack(spacing: 2) {
                        Text(entry.positionDisplay)
                            .font(.caption2)
                        Text(entry.playerName.components(separatedBy: " ").first ?? "")
                            .font(.caption.bold())
                        Text(entry.relativeToParDisplay)
                            .font(.caption)
                            .foregroundColor(entry.relativeToPar <= 0 ? .red : .primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        entry.playerId == authViewModel.currentUser?.id
                        ? Color.green.opacity(0.2)
                        : Color.clear
                    )
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Hole Selector (Swipeable)
    
    private var holeSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...18, id: \.self) { hole in
                        Button(action: { selectedHole = hole }) {
                            VStack(spacing: 2) {
                                Text("\(hole)")
                                    .font(.headline)
                                Text("Par \(course.holes.count >= hole ? course.holes[hole-1].par : 4)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 44, height: 50)
                            .background(
                                selectedHole == hole
                                ? Color.green
                                : Color(.systemGray5)
                            )
                            .foregroundColor(selectedHole == hole ? .white : .primary)
                            .cornerRadius(8)
                        }
                        .id(hole)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedHole) { _, newHole in
                withAnimation {
                    proxy.scrollTo(newHole, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Score Entry
    
    private var scoreEntryArea: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Hole Info
            VStack(spacing: 4) {
                Text("Hole \(selectedHole)")
                    .font(.title.bold())
                
                if course.holes.count >= selectedHole {
                    let hole = course.holes[selectedHole - 1]
                    HStack(spacing: 16) {
                        Label("Par \(hole.par)", systemImage: "flag")
                        Label("\(hole.yardage) yds", systemImage: "ruler")
                        Label("HCP \(hole.handicapIndex)", systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Stroke Counter
            VStack(spacing: 8) {
                Text("Strokes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 24) {
                    Button(action: { if strokeCount > 1 { strokeCount -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                    
                    Text("\(strokeCount)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .frame(minWidth: 80)
                    
                    Button(action: { strokeCount += 1 }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                }
                
                // Score label (birdie, par, bogey, etc.)
                if course.holes.count >= selectedHole {
                    let par = course.holes[selectedHole - 1].par
                    Text(scoreLabel(strokes: strokeCount, par: par))
                        .font(.subheadline.bold())
                        .foregroundColor(scoreLabelColor(strokes: strokeCount, par: par))
                }
            }
            
            // Putt Counter
            VStack(spacing: 8) {
                Text("Putts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 24) {
                    Button(action: { if puttCount > 0 { puttCount -= 1 } }) {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(puttCount)")
                        .font(.title2.bold())
                        .frame(minWidth: 40)
                    
                    Button(action: { puttCount += 1 }) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack {
            // Previous hole
            Button(action: { if selectedHole > 1 { selectedHole -= 1; resetCounters() } }) {
                Image(systemName: "chevron.left")
                    .padding()
            }
            .disabled(selectedHole == 1)
            
            Spacer()
            
            // Submit Score
            Button(action: submitScore) {
                Text("Save & Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(25)
            }
            
            Spacer()
            
            // Next hole
            Button(action: { if selectedHole < 18 { selectedHole += 1; resetCounters() } }) {
                Image(systemName: "chevron.right")
                    .padding()
            }
            .disabled(selectedHole == 18)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func submitScore() {
        guard let userId = authViewModel.currentUser?.id,
              let userName = authViewModel.currentUser?.displayName else { return }
        
        Task {
            await roundVM.submitScore(
                roundId: roundId,
                userId: userId,
                userName: userName,
                holeNumber: selectedHole,
                strokes: strokeCount,
                putts: puttCount
            )
            
            // Auto-advance
            if selectedHole < 18 {
                selectedHole += 1
                resetCounters()
            }
        }
    }
    
    private func resetCounters() {
        if course.holes.count >= selectedHole {
            strokeCount = course.holes[selectedHole - 1].par
        } else {
            strokeCount = 4
        }
        puttCount = 2
    }
    
    private func scoreLabel(strokes: Int, par: Int) -> String {
        switch strokes - par {
        case ...(-3): return "Albatross! 🦅🦅"
        case -2: return "Eagle! 🦅"
        case -1: return "Birdie 🐦"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case 3: return "Triple Bogey 😬"
        default: return "💀"
        }
    }
    
    private func scoreLabelColor(strokes: Int, par: Int) -> Color {
        switch strokes - par {
        case ...(-1): return .red // Under par = red (golf tradition)
        case 0: return .primary
        default: return .blue // Over par = blue
        }
    }
}
