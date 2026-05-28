import SwiftUI

struct StartRoundView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var roundVM = RoundViewModel()
    
    @State private var searchText = ""
    @State private var selectedCourse: Course?
    @State private var selectedFormat: ScoringFormat = .strokePlay
    @State private var selectedGames: Set<GameType> = []
    @State private var invitedFriends: [HWHUser] = []
    @State private var friends: [HWHUser] = []
    @State private var isSearching = false
    @State private var searchResults: [Course] = []
    @State private var step: SetupStep = .course
    
    enum SetupStep {
        case course, format, friends, confirm
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress Indicator
                progressBar
                
                switch step {
                case .course:
                    courseSelectionStep
                case .format:
                    formatSelectionStep
                case .friends:
                    friendsSelectionStep
                case .confirm:
                    confirmationStep
                }
            }
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if let userId = authViewModel.currentUser?.id {
                    friends = await FirebaseService.shared.getFriends(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= stepIndex ? Color.green : Color(.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var stepIndex: Int {
        switch step {
        case .course: return 0
        case .format: return 1
        case .friends: return 2
        case .confirm: return 3
        }
    }
    
    // MARK: - Step 1: Course Selection
    
    private var courseSelectionStep: some View {
        VStack(spacing: 16) {
            Text("Where are you playing?")
                .font(.title2.bold())
                .padding(.top)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search courses...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            if newValue.count >= 3 {
                                searchResults = await FirebaseService.shared.searchCourses(query: newValue)
                            }
                        }
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Results
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(searchResults) { course in
                        Button(action: {
                            selectedCourse = course
                            step = .format
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(course.name)
                                        .font(.subheadline.bold())
                                    Text("\(course.city), \(course.state)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Format Selection
    
    private var formatSelectionStep: some View {
        VStack(spacing: 24) {
            Text("How are you playing?")
                .font(.title2.bold())
                .padding(.top)
            
            // Scoring Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Scoring Format")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                ForEach(ScoringFormat.allCases, id: \.self) { format in
                    Button(action: { selectedFormat = format }) {
                        HStack {
                            Image(systemName: format.icon)
                                .frame(width: 24)
                            Text(format.description)
                            Spacer()
                            if selectedFormat == format {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(selectedFormat == format ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            // Side Games
            VStack(alignment: .leading, spacing: 8) {
                Text("Side Games (Optional)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                ForEach(GameType.allCases, id: \.self) { game in
                    Button(action: {
                        if selectedGames.contains(game) {
                            selectedGames.remove(game)
                        } else {
                            selectedGames.insert(game)
                        }
                    }) {
                        HStack {
                            Image(systemName: game.icon)
                                .frame(width: 24)
                            Text(game.description)
                            Spacer()
                            if selectedGames.contains(game) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(selectedGames.contains(game) ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            nextButton(action: { step = .friends })
        }
    }
    
    // MARK: - Step 3: Friends Selection
    
    private var friendsSelectionStep: some View {
        VStack(spacing: 16) {
            Text("Who's playing?")
                .font(.title2.bold())
                .padding(.top)
            
            Text("They'll get a notification to join.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(friends) { friend in
                        Button(action: {
                            if invitedFriends.contains(where: { $0.id == friend.id }) {
                                invitedFriends.removeAll { $0.id == friend.id }
                            } else {
                                invitedFriends.append(friend)
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(friend.displayName.prefix(1)))
                                            .font(.subheadline.bold())
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text(friend.displayName)
                                        .font(.subheadline)
                                    if let hcp = friend.handicap {
                                        Text("HCP: \(String(format: "%.1f", hcp))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if invitedFriends.contains(where: { $0.id == friend.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
            }
            
            nextButton(action: { step = .confirm })
        }
    }
    
    // MARK: - Step 4: Confirmation
    
    private var confirmationStep: some View {
        VStack(spacing: 24) {
            Text("Ready to tee off?")
                .font(.title2.bold())
                .padding(.top)
            
            // Summary Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.green)
                    Text(selectedCourse?.name ?? "")
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: selectedFormat.icon)
                        .foregroundColor(.green)
                    Text(selectedFormat.description)
                }
                
                if !selectedGames.isEmpty {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(.green)
                        Text(selectedGames.map { $0.description }.joined(separator: ", "))
                            .font(.subheadline)
                    }
                }
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.green)
                    Text("You + \(invitedFriends.count) friends")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Start Button
            Button(action: startRound) {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("Let's Go!")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Next Button
    
    private func nextButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Next")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Start Round
    
    private func startRound() {
        guard let course = selectedCourse,
              let userId = authViewModel.currentUser?.id else { return }
        
        let playerIds = [userId] + invitedFriends.map { $0.id }
        
        Task {
            let _ = await roundVM.createRound(
                course: course,
                format: selectedFormat,
                games: Array(selectedGames),
                players: playerIds,
                createdBy: userId
            )
            dismiss()
        }
    }
}
