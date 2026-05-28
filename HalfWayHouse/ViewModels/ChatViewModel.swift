import Foundation
import FirebaseDatabase

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    private var messagesListener: DatabaseHandle?
    private var chatRef: DatabaseReference?
    
    deinit {
        stopListening()
    }
    
    // MARK: - Listen to Chat
    
    func listenToChat(roundId: String) {
        stopListening()
        
        let ref = Database.database().reference(withPath: "rounds/\(roundId)/chat")
        chatRef = ref
        
        // Listen for new messages (last 50)
        let query = ref.queryOrdered(byChild: "timestamp").queryLimited(toLast: 50)
        
        messagesListener = query.observe(.value) { [weak self] snapshot in
            var newMessages: [ChatMessage] = []
            
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any] else { continue }
                
                let message = ChatMessage(
                    id: snap.key,
                    roundId: roundId,
                    userId: data["userId"] as? String ?? "",
                    userName: data["userName"] as? String ?? "",
                    type: MessageType(rawValue: data["type"] as? String ?? "text") ?? .text,
                    text: data["text"] as? String,
                    imageURL: data["imageURL"] as? String,
                    holeNumber: data["holeNumber"] as? Int,
                    timestamp: Date(timeIntervalSince1970: data["timestamp"] as? TimeInterval ?? 0)
                )
                newMessages.append(message)
            }
            
            Task { @MainActor in
                self?.messages = newMessages
            }
        }
    }
    
    func stopListening() {
        if let listener = messagesListener, let ref = chatRef {
            ref.removeObserver(withHandle: listener)
        }
        messagesListener = nil
        chatRef = nil
    }
    
    // MARK: - Send Message
    
    func sendMessage(roundId: String, userId: String, userName: String, text: String) async {
        let message = ChatMessage(
            id: UUID().uuidString,
            roundId: roundId,
            userId: userId,
            userName: userName,
            type: .text,
            text: text,
            imageURL: nil,
            holeNumber: nil,
            timestamp: Date()
        )
        
        await FirebaseService.shared.sendChatMessage(message)
    }
    
    // MARK: - Send Photo
    
    func sendPhoto(roundId: String, userId: String, userName: String, imageData: Data, holeNumber: Int?) async {
        // Upload image to Firebase Storage
        guard let imageURL = await FirebaseService.shared.uploadImage(
            imageData: imageData,
            path: "rounds/\(roundId)/photos/\(UUID().uuidString).jpg"
        ) else { return }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            roundId: roundId,
            userId: userId,
            userName: userName,
            type: .photo,
            text: nil,
            imageURL: imageURL,
            holeNumber: holeNumber,
            timestamp: Date()
        )
        
        await FirebaseService.shared.sendChatMessage(message)
    }
    
    // MARK: - React to Score
    
    func reactToScore(roundId: String, userId: String, userName: String, targetPlayerId: String, holeNumber: Int, emoji: String) async {
        let message = ChatMessage(
            id: UUID().uuidString,
            roundId: roundId,
            userId: userId,
            userName: userName,
            type: .reaction,
            text: "\(userName) reacted \(emoji) to Hole \(holeNumber)",
            imageURL: nil,
            holeNumber: holeNumber,
            timestamp: Date()
        )
        
        await FirebaseService.shared.sendChatMessage(message)
    }
}
