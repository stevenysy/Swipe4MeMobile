//
//  ChatConversationView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 1/2/25.
//

import SwiftUI
import FirebaseAuth

struct ChatConversationView: View {
    let chatRoom: ChatRoom
    let swipeRequest: SwipeRequest
    
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var isChatActive = true
    
    @Environment(\.dismiss) private var dismiss
    
    private let chatManager = ChatManager.shared
    private let userManager = UserManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            chatHeaderView
            
            Divider()
            
            // Messages List
            messagesListView
            
            Divider()
            
            // Message Input
            messageInputView
        }
        .navigationBarHidden(true)
        .onAppear {
            startListeningToMessages()
            isChatActive = chatRoom.isActive
            
            // Reset unread count when user opens the chat
            Task {
                await chatManager.resetUnreadCount(for: chatRoom.requestId)
            }
        }
        .onDisappear {
            stopListeningToMessages()
            
            // Reset unread count when user exits chat (covers all edge cases)
            Task {
                await chatManager.resetUnreadCount(for: chatRoom.requestId)
            }
        }
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var chatHeaderView: some View {
        HStack {
            // Back Button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Chat Info
            VStack(alignment: .center, spacing: 2) {
                Text(swipeRequest.location.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Meeting at: \(swipeRequest.meetingTime.dateValue(), style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Other User Info
            if let otherUserId = chatManager.getOtherParticipantId(in: chatRoom) {
                UserInfoView(userId: otherUserId)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Messages List
    
    @ViewBuilder
    private var messagesListView: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading messages...")
                .foregroundColor(.secondary)
            Spacer()
        } else if messages.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "message")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No messages yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Start the conversation!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping on empty state
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: isCurrentUserMessage(message)
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping on messages
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onChange(of: messages.count) { _, _ in
                    // Auto-scroll to bottom when new messages arrive
                    if let lastMessage = messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Instantly show latest messages when entering chat
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Message Input
    
    @ViewBuilder
    private var messageInputView: some View {
        HStack(spacing: 12) {
            if isChatActive {
                // Text Input
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                // Send Button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            } else {
                // Disabled input for closed chats
                HStack {
                    Spacer()
                    Text("This chat has been closed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Properties
    
    private var canSendMessage: Bool {
        isChatActive && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func isCurrentUserMessage(_ message: ChatMessage) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return message.senderId == currentUserId
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear input immediately
        
        Task {
            await chatManager.sendUserMessage(content: content, to: chatRoom.requestId)
        }
    }
    
    private func startListeningToMessages() {
        chatManager.startListeningToMessages(in: chatRoom.requestId) { updatedMessages in
            withAnimation(.easeInOut(duration: 0.2)) {
                messages = updatedMessages
                isLoading = false
            }
        }
        
        // Also listen for chat room status changes
        chatManager.startListeningToChatRoomStatus(in: chatRoom.requestId) { isActive in
            withAnimation(.easeInOut(duration: 0.2)) {
                isChatActive = isActive
            }
        }
    }
    
    private func stopListeningToMessages() {
        chatManager.stopListeningToMessages(in: chatRoom.requestId)
        chatManager.stopListeningToChatRoomStatus(in: chatRoom.requestId)
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    var body: some View {
        if message.messageType.isSystemMessage {
            // System messages centered with no spacing constraints
            HStack {
                Spacer()
                systemMessageView
                Spacer()
            }
        } else {
            // User messages with normal bubble layout
            HStack {
                if isCurrentUser {
                    Spacer(minLength: 50)
                }
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    userMessageView
                    
                    // Timestamp for user messages only
                    Text(message.timestamp.dateValue().chatTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !isCurrentUser {
                    Spacer(minLength: 50)
                }
            }
        }
    }
    
    @ViewBuilder
    private var systemMessageView: some View {
        VStack(spacing: 4) {
            // Timestamp centered above the message
            Text(message.timestamp.dateValue().chatTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // System message as plain text
            Text(message.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var userMessageView: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(isCurrentUser ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isCurrentUser ? Color.blue : Color(.systemGray5))
            .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ChatConversationView(
            chatRoom: ChatRoom.mockChatRoom,
            swipeRequest: SwipeRequest.mockRequests[0]
        )
    }
} 