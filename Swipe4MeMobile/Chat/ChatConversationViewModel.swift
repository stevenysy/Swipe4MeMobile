//
//  ChatConversationViewModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 1/2/25.
//

import SwiftUI
import FirebaseAuth

@Observable
@MainActor
final class ChatConversationViewModel {
    // MARK: - Published Properties
    var messages: [ChatMessage] = []
    var messageText = ""
    var isLoading = true
    var isChatActive = true
    
    // MARK: - Private Properties
    private let chatRoom: ChatRoom
    private let swipeRequest: SwipeRequest
    
    // MARK: - Dependencies
    private let chatManager = ChatManager.shared
    private let userManager = UserManager.shared
    
    // MARK: - Initialization
    
    init(chatRoom: ChatRoom, swipeRequest: SwipeRequest) {
        self.chatRoom = chatRoom
        self.swipeRequest = swipeRequest
    }
    
    // MARK: - Computed Properties
    
    var canSendMessage: Bool {
        isChatActive && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var otherParticipantId: String? {
        chatManager.getOtherParticipantId(in: chatRoom)
    }
    
    // MARK: - Public Methods
    
    func onAppear() {
        startListeningToMessages()
        isChatActive = chatRoom.isActive
        
        Task {
            // Set active chat for notification filtering
            await chatManager.setActiveChat(chatRoom.requestId)
            
            // Reset unread count when user opens the chat
            await chatManager.resetUnreadCount(for: chatRoom.requestId)
        }
    }
    
    func onDisappear() {
        stopListeningToMessages()
        
        Task {
            // Clear active chat when user leaves
            await chatManager.clearActiveChat()
            
            // Reset unread count when user exits chat (covers all edge cases)
            await chatManager.resetUnreadCount(for: chatRoom.requestId)
        }
    }
    
    func sendMessage() {
        guard canSendMessage else { return }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear input immediately
        
        Task {
            await chatManager.sendUserMessage(content: content, to: chatRoom.requestId)
        }
    }
    
    func isCurrentUserMessage(_ message: ChatMessage) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return message.senderId == currentUserId
    }
    
    // MARK: - Private Methods
    
    private func startListeningToMessages() {
        chatManager.startListeningToMessages(in: chatRoom.requestId) { [weak self] updatedMessages in
            guard let self = self else { return }
            
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.messages = updatedMessages
                    self.isLoading = false
                }
            }
        }
        
        // Also listen for chat room status changes
        chatManager.startListeningToChatRoomStatus(in: chatRoom.requestId) { [weak self] isActive in
            guard let self = self else { return }
            
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isChatActive = isActive
                }
            }
        }
    }
    
    private func stopListeningToMessages() {
        chatManager.stopListeningToMessages(in: chatRoom.requestId)
        chatManager.stopListeningToChatRoomStatus(in: chatRoom.requestId)
    }
} 