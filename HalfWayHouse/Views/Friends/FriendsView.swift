import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var friends: [HWHUser] = []
    @State private var showInvite = false
    @State private var inviteCode = ""
    @State private var redeemCode = ""
    @State private var showRedeemAlert = false
    @State private var redeemMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Invite Section
                    inviteSection
                    
                    // Friends List
                    if friends.isEmpty {
                        emptyState
                    } else {
                        friendsList
                    }
                }
                .padding()
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: generateInvite) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.green)
                    }
                }
            }
            .task {
                await loadFriends()
            }
            .alert("Friend Added!", isPresented: $showRedeemAlert) {
                Button("OK") { }
            } message: {
                Text(redeemMessage)
            }
        }
    }
    
    // MARK: - Invite Section
    
    private var inviteSection: some View {
        VStack(spacing: 12) {
            // Show invite code if generated
            if !inviteCode.isEmpty {
                VStack(spacing: 8) {
                    Text("Your Invite Code")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Text(inviteCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text("Share this code with your friends. Expires in 7 days.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Copy Code") {
                        UIPasteboard.general.string = inviteCode
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Redeem code input
            HStack {
                TextField("Enter friend's code", text: $redeemCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                
                Button("Add") {
                    Task { await redeemInvite() }
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(redeemCode.count == 6 ? Color.green : Color.gray)
                .cornerRadius(8)
                .disabled(redeemCode.count != 6)
            }
        }
    }
    
    // MARK: - Friends List
    
    private var friendsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Crew (\(friends.count))")
                .font(.headline)
            
            ForEach(friends) { friend in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(friend.displayName.prefix(1)))
                                .font(.headline)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName)
                            .font(.subheadline.bold())
                        HStack(spacing: 8) {
                            if let hcp = friend.handicap {
                                Text("HCP \(String(format: "%.1f", hcp))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let course = friend.homeCourse {
                                Text(course)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Online indicator (future: show if they're in an active round)
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 50))
                .foregroundColor(.green.opacity(0.5))
            
            Text("No Friends Yet")
                .font(.title3.bold())
            
            Text("Generate an invite code and share it with your golf buddies, or enter a code from a friend.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Actions
    
    private func generateInvite() {
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            inviteCode = await FirebaseService.shared.generateInviteCode(userId: userId)
        }
    }
    
    private func redeemInvite() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        let success = await FirebaseService.shared.redeemInviteCode(code: redeemCode, userId: userId)
        
        if success {
            redeemMessage = "Friend added successfully! 🎉"
            redeemCode = ""
            await loadFriends()
        } else {
            redeemMessage = "Invalid or expired code. Try again."
        }
        showRedeemAlert = true
    }
    
    private func loadFriends() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        friends = await FirebaseService.shared.getFriends(userId: userId)
    }
}
