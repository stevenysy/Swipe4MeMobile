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
    var unreadCounts: [String: Int] = [:]  // Track unread counts per user
    
    init(
        requestId: String,
        requesterId: String,
        swiperId: String,
        createdAt: Timestamp = Timestamp(),
        lastMessageAt: Timestamp? = nil,
        lastMessage: String? = nil,
        isActive: Bool = true,
        unreadCounts: [String: Int] = [:]
    ) {
        self.requestId = requestId
        self.requesterId = requesterId
        self.swiperId = swiperId
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.lastMessage = lastMessage
        self.isActive = isActive
        self.unreadCounts = unreadCounts
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
    
    // MARK: - Unread Message Management
    
    /// Gets the unread count for a specific user
    func getUnreadCount(for userId: String) -> Int {
        return unreadCounts[userId] ?? 0
    }
    
    /// Resets unread count to 0 for a specific user (when they open the chat)
    mutating func resetUnreadCount(for userId: String) {
        unreadCounts[userId] = 0
    }
    
    /// Increments unread count for a specific user (when they receive a message)
    mutating func incrementUnreadCount(for userId: String) {
        let currentCount = unreadCounts[userId] ?? 0
        unreadCounts[userId] = currentCount + 1
    }
    
    /// Initializes unread counts for both participants if not already set
    mutating func initializeUnreadCounts() {
        if unreadCounts[requesterId] == nil {
            unreadCounts[requesterId] = 0
        }
        if unreadCounts[swiperId] == nil {
            unreadCounts[swiperId] = 0
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
    
    init(
        chatRoomId: String,
        senderId: String,
        content: String,
        timestamp: Timestamp = Timestamp(),
        messageType: MessageType = .userMessage
    ) {
        self.chatRoomId = chatRoomId
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.messageType = messageType
    }
}

// MARK: - MessageType Enum

extension ChatMessage {
    enum MessageType: String, Codable, CaseIterable {
        case userMessage = "userMessage"
        case systemNotification = "systemNotification"
        
        var displayName: String {
            switch self {
            case .userMessage:
                return "Message"
            case .systemNotification:
                return "System Notification"
            }
        }
        
        var isSystemMessage: Bool {
            return self == .systemNotification
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
            lastMessage: "Thanks for accepting my request!",
            unreadCounts: [
                "user_requester_1": 0,
                "user_swiper_1": 2
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