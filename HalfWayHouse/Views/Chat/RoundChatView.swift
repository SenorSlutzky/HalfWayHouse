import SwiftUI

struct RoundChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatVM = ChatViewModel()
    @State private var messageText = ""
    @State private var showPhotoPicker = false
    
    let roundId: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chatVM.messages) { message in
                                chatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatVM.messages.count) { _, _ in
                        if let lastMessage = chatVM.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input Bar
                inputBar
            }
            .navigationTitle("Round Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                chatVM.listenToChat(roundId: roundId)
            }
            .onDisappear {
                chatVM.stopListening()
            }
        }
    }
    
    // MARK: - Chat Bubble
    
    private func chatBubble(message: ChatMessage) -> some View {
        let isMe = message.userId == authViewModel.currentUser?.id
        let isSystem = message.type == .scoreAlert || message.type == .roundEvent
        
        return HStack {
            if isMe { Spacer() }
            
            if isSystem {
                // System message (score alerts, events)
                Text(message.text ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                    if !isMe {
                        Text(message.userName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let imageURL = message.imageURL {
                        // Photo message
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(12)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 200, height: 150)
                                .overlay(ProgressView())
                        }
                    } else {
                        // Text message
                        Text(message.text ?? "")
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isMe ? Color.green : Color(.systemGray5))
                            .foregroundColor(isMe ? .white : .primary)
                            .cornerRadius(16)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !isMe && !isSystem { Spacer() }
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Photo button
            Button(action: { showPhotoPicker = true }) {
                Image(systemName: "camera.fill")
                    .foregroundColor(.green)
            }
            
            // Text field
            TextField("Talk smack...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(sendMessage)
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? .gray : .green)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userId = authViewModel.currentUser?.id,
              let userName = authViewModel.currentUser?.displayName else { return }
        
        let text = messageText
        messageText = ""
        
        Task {
            await chatVM.sendMessage(roundId: roundId, userId: userId, userName: userName, text: text)
        }
    }
}
