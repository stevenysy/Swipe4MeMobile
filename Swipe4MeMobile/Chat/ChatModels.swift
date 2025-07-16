//
//  ChatModels.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 1/2/25.
//

import FirebaseFirestore
import Foundation

// MARK: - ChatRoom Model

struct ChatRoom: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    let requestId: String
    let requesterId: String
    var swiperId: String  // Can be updated when swiper changes
    let createdAt: Timestamp
    var lastMessageAt: Timestamp?
    var lastMessage: String?
    var isActive: Bool = true  // Chat room is active by default
    
    init(
        requestId: String,
        requesterId: String,
        swiperId: String,
        createdAt: Timestamp = Timestamp(),
        lastMessageAt: Timestamp? = nil,
        lastMessage: String? = nil,
        isActive: Bool = true
    ) {
        self.requestId = requestId
        self.requesterId = requesterId
        self.swiperId = swiperId
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.lastMessage = lastMessage
        self.isActive = isActive
    }
    
    /// Returns the other participant's ID (not the current user)
    func getOtherParticipantId(currentUserId: String) -> String? {
        if currentUserId == requesterId {
            return swiperId
        } else if currentUserId == swiperId {
            return requesterId
        }
        return nil
    }
    
    /// Checks if the current user is the requester
    func isRequester(userId: String) -> Bool {
        return userId == requesterId
    }
    
    /// Checks if the current user is the swiper
    func isSwiper(userId: String) -> Bool {
        return userId == swiperId
    }
    
    /// Checks if the user is a participant in this chat room
    func isParticipant(userId: String) -> Bool {
        return userId == requesterId || userId == swiperId
    }
    
    /// Updates the swiper for this chat room (when someone new accepts the request)
    mutating func updateSwiper(newSwiperId: String) {
        self.swiperId = newSwiperId
    }
    
    /// Closes the chat room (when request is cancelled or completed)
    mutating func closeChatRoom() {
        self.isActive = false
    }
}

// MARK: - UserUnreadCounts Model

struct UserUnreadCounts: Codable, Identifiable, Equatable {
    @DocumentID var id: String?  // This will be the userId
    var chatRoomCounts: [String: Int] = [:]  // chatRoomId -> unread count
    var lastUpdated: Timestamp = Timestamp()
    
    init(userId: String? = nil, chatRoomCounts: [String: Int] = [:]) {
        self.id = userId
        self.chatRoomCounts = chatRoomCounts
        self.lastUpdated = Timestamp()
    }
    
    /// Gets the unread count for a specific chat room
    func getUnreadCount(for chatRoomId: String) -> Int {
        return chatRoomCounts[chatRoomId] ?? 0
    }
    
    /// Sets the unread count for a specific chat room
    mutating func setUnreadCount(for chatRoomId: String, count: Int) {
        chatRoomCounts[chatRoomId] = max(0, count) // Ensure non-negative
        lastUpdated = Timestamp()
    }
    
    /// Resets unread count to 0 for a specific chat room
    mutating func resetUnreadCount(for chatRoomId: String) {
        chatRoomCounts[chatRoomId] = 0
        lastUpdated = Timestamp()
    }
    
    /// Increments unread count for a specific chat room
    mutating func incrementUnreadCount(for chatRoomId: String) {
        let currentCount = chatRoomCounts[chatRoomId] ?? 0
        chatRoomCounts[chatRoomId] = currentCount + 1
        lastUpdated = Timestamp()
    }
    
    /// Removes a chat room from unread counts (when chat room is deleted)
    mutating func removeChatRoom(_ chatRoomId: String) {
        chatRoomCounts.removeValue(forKey: chatRoomId)
        lastUpdated = Timestamp()
    }
    
    /// Gets total unread count across all chat rooms
    var totalUnreadCount: Int {
        return chatRoomCounts.values.reduce(0, +)
    }
    
    /// Gets all chat rooms with unread messages
    var chatRoomsWithUnreadMessages: [String] {
        return chatRoomCounts.compactMap { key, value in
            value > 0 ? key : nil
        }
    }
}

// MARK: - ChatMessage Model

struct ChatMessage: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    let chatRoomId: String
    let senderId: String
    let content: String
    let timestamp: Timestamp
    let messageType: MessageType
    
    // MARK: - Change Proposal Fields
    var proposalId: String? // Links to ChangeProposal document
    
    init(
        chatRoomId: String,
        senderId: String,
        content: String,
        timestamp: Timestamp = Timestamp(),
        messageType: MessageType = .userMessage,
        proposalId: String? = nil
    ) {
        self.chatRoomId = chatRoomId
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.messageType = messageType
        self.proposalId = proposalId
    }
}

// MARK: - MessageType Enum

extension ChatMessage {
    enum MessageType: String, Codable, CaseIterable {
        case userMessage = "userMessage"
        case systemNotification = "systemNotification"
        case changeProposal = "changeProposal"
        
        var displayName: String {
            switch self {
            case .userMessage:
                return "Message"
            case .systemNotification:
                return "System Notification"
            case .changeProposal:
                return "Change Proposal"
            }
        }
        
        var isSystemMessage: Bool {
            return self == .systemNotification || self == .changeProposal
        }
        
        var isInteractive: Bool {
            return self == .changeProposal
        }
    }
}



// MARK: - System Message Helpers

extension ChatMessage {
    /// Creates a system notification message for request status changes
    static func createSystemMessage(
        chatRoomId: String,
        content: String,
        timestamp: Timestamp = Timestamp()
    ) -> ChatMessage {
        return ChatMessage(
            chatRoomId: chatRoomId,
            senderId: "system",
            content: content,
            timestamp: timestamp,
            messageType: .systemNotification
        )
    }
    
    /// Creates system messages for common request events
    static func requestAccepted(chatRoomId: String, swiperName: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "\(swiperName) accepted the swipe request"
        )
    }
    
    static func requestCancelled(chatRoomId: String, cancelledBy: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "\(cancelledBy) cancelled the request"
        )
    }
    
    static func requestCompleted(chatRoomId: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "Swipe request completed successfully! 🎉"
        )
    }
    
    static func requestInProgress(chatRoomId: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "Request is now in progress. Time to meet up!"
        )
    }
    
    static func requestAwaitingReview(chatRoomId: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "Swipe received! Awaiting confirmation from requester."
        )
    }
    
    static func swiperChanged(chatRoomId: String, newSwiperName: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "\(newSwiperName) is now the swiper for this request"
        )
    }
    
    static func chatClosed(chatRoomId: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "This chat has been closed due to request cancellation"
        )
    }
    
    // MARK: - Change Proposal Messages
    
    /// Creates an interactive proposal message
    static func createProposalMessage(
        chatRoomId: String,
        proposalId: String,
        proposerName: String,
        changesDescription: String
    ) -> ChatMessage {
        let content = "\(proposerName) proposed changes to the request:\n\n\(changesDescription)"
        
        return ChatMessage(
            chatRoomId: chatRoomId,
            senderId: "system",
            content: content,
            messageType: .changeProposal,
            proposalId: proposalId
        )
    }
    
    /// Creates system message for proposal acceptance
    static func proposalAccepted(chatRoomId: String, acceptedBy: String, changesDescription: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "\(acceptedBy) accepted the proposed changes:\n\(changesDescription)"
        )
    }
    
    /// Creates system message for proposal decline
    static func proposalDeclined(chatRoomId: String, declinedBy: String) -> ChatMessage {
        return createSystemMessage(
            chatRoomId: chatRoomId,
            content: "\(declinedBy) declined the proposed changes"
        )
    }
}

// MARK: - Mock Data for Previews

#if DEBUG
extension ChatRoom {
    static var mockChatRoom: ChatRoom {
        return ChatRoom(
            requestId: "mock_request_1",
            requesterId: "user_requester_1",
            swiperId: "user_swiper_1",
            createdAt: Timestamp(date: Date().addingTimeInterval(-3600)),
            lastMessageAt: Timestamp(date: Date().addingTimeInterval(-300)),
            lastMessage: "Thanks for accepting my request!"
        )
    }
}

extension UserUnreadCounts {
    static var mockUserUnreadCounts: UserUnreadCounts {
        return UserUnreadCounts(
            userId: "user_requester_1",
            chatRoomCounts: [
                "mock_request_1": 2,
                "mock_request_2": 0,
                "mock_request_3": 1
            ]
        )
    }
}

extension ChatMessage {
    static var mockMessages: [ChatMessage] {
        let chatRoomId = "mock_chat_room_1"
        return [
            ChatMessage.createSystemMessage(
                chatRoomId: chatRoomId,
                content: "John accepted the swipe request",
                timestamp: Timestamp(date: Date().addingTimeInterval(-3600))
            ),
            ChatMessage(
                chatRoomId: chatRoomId,
                senderId: "user_requester_1",
                content: "Thanks for accepting my request!",
                timestamp: Timestamp(date: Date().addingTimeInterval(-3000)),
                messageType: .userMessage
            ),
            ChatMessage(
                chatRoomId: chatRoomId,
                senderId: "user_swiper_1",
                content: "No problem! I'll be there at 6 PM.",
                timestamp: Timestamp(date: Date().addingTimeInterval(-2400)),
                messageType: .userMessage
            ),
            ChatMessage.createSystemMessage(
                chatRoomId: chatRoomId,
                content: "Request is now in progress. Time to meet up!",
                timestamp: Timestamp(date: Date().addingTimeInterval(-1800))
            ),
            ChatMessage(
                chatRoomId: chatRoomId,
                senderId: "user_requester_1",
                content: "I'm here at the entrance!",
                timestamp: Timestamp(date: Date().addingTimeInterval(-300)),
                messageType: .userMessage
            )
        ]
    }
}
#endif 