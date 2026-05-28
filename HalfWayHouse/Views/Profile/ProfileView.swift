import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isEditingHandicap = false
    @State private var handicapText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Grid
                    statsGrid
                    
                    // Settings
                    settingsSection
                    
                    // Sign Out
                    signOutButton
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(authViewModel.currentUser?.displayName.prefix(1) ?? "?"))
                        .font(.title.bold())
                        .foregroundColor(.white)
                )
            
            Text(authViewModel.currentUser?.displayName ?? "Golfer")
                .font(.title2.bold())
            
            // Handicap
            HStack(spacing: 4) {
                Text("Handicap:")
                    .foregroundColor(.secondary)
                
                if isEditingHandicap {
                    TextField("0.0", text: $handicapText)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Save") {
                        if let hcp = Double(handicapText) {
                            Task { await authViewModel.updateHandicap(hcp) }
                        }
                        isEditingHandicap = false
                    }
                    .foregroundColor(.green)
                } else {
                    Text(authViewModel.currentUser?.handicapDisplay ?? "N/A")
                        .font(.headline)
                    
                    Button(action: {
                        handicapText = authViewModel.currentUser?.handicap.map { String(format: "%.1f", $0) } ?? ""
                        isEditingHandicap = true
                    }) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.green)
                    }
                }
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statCard(title: "Rounds", value: "0", icon: "flag.fill")
            statCard(title: "Avg Score", value: "--", icon: "chart.line.uptrend.xyaxis")
            statCard(title: "Best", value: "--", icon: "trophy.fill")
            statCard(title: "Birdies", value: "0", icon: "bird")
            statCard(title: "Skins Won", value: "0", icon: "dollarsign.circle")
            statCard(title: "Matches", value: "0-0", icon: "person.2")
        }
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Settings
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)
            
            settingsRow(icon: "bell.fill", title: "Notifications", color: .orange)
            settingsRow(icon: "lock.fill", title: "Privacy", color: .blue)
            settingsRow(icon: "questionmark.circle.fill", title: "Help & Feedback", color: .purple)
        }
    }
    
    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Sign Out
    
    private var signOutButton: some View {
        Button(action: { authViewModel.signOut() }) {
            Text("Sign Out")
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}
