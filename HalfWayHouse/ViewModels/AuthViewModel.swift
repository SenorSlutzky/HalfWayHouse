import Foundation
import FirebaseAuth
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: HWHUser?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        listenToAuthState()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func listenToAuthState() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.fetchUserProfile(uid: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to get Apple ID token"
            return
        }
        
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        
        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            let uid = result.user.uid
            
            // Check if user profile exists, create if new
            let exists = await FirebaseService.shared.userExists(uid: uid)
            if !exists {
                let displayName = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName
                ].compactMap { $0 }.joined(separator: " ")
                
                let newUser = HWHUser(
                    id: uid,
                    displayName: displayName.isEmpty ? "Golfer" : displayName,
                    email: credential.email ?? result.user.email ?? "",
                    handicap: nil,
                    homeCourse: nil,
                    avatarURL: nil,
                    friends: [],
                    createdAt: Date()
                )
                await FirebaseService.shared.createUser(newUser)
            }
            
            await fetchUserProfile(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Email Sign In (for development/testing)
    
    func signInWithEmail(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await fetchUserProfile(uid: result.user.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createAccount(email: String, password: String, displayName: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            
            let newUser = HWHUser(
                id: uid,
                displayName: displayName,
                email: email,
                handicap: nil,
                homeCourse: nil,
                avatarURL: nil,
                friends: [],
                createdAt: Date()
            )
            await FirebaseService.shared.createUser(newUser)
            await fetchUserProfile(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Profile
    
    func fetchUserProfile(uid: String) async {
        currentUser = await FirebaseService.shared.getUser(uid: uid)
        isAuthenticated = currentUser != nil
    }
    
    func updateHandicap(_ handicap: Double) async {
        guard var user = currentUser else { return }
        user.handicap = handicap
        await FirebaseService.shared.updateUser(user)
        currentUser = user
    }
}
