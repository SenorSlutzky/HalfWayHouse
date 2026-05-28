import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentNonce: String?
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo & Branding
            VStack(spacing: 16) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Half Way House")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("The turn just got interesting.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sign In Button
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn, onRequest: configureAppleSignIn, onCompletion: handleAppleSignIn)
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 55)
                    .cornerRadius(12)
                
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
                .frame(height: 60)
        }
        .padding()
    }
    
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else { return }
            Task {
                await authViewModel.signInWithApple(credential: credential, nonce: nonce)
            }
        case .failure(let error):
            authViewModel.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Crypto Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
