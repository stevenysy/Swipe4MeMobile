//
//  ChatManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 1/2/25.
//

import FirebaseFirestore
import FirebaseAuth
import Foundation

@Observable
@MainActor
final class ChatManager {
    static let shared = ChatManager()
    
    private let db = Firestore.firestore()
    private let userManager = UserManager.shared
    
    // MARK: - Published Properties
    var errorMessage = ""
    private var chatRoomListeners: [String: ListenerRegistration] = [:]
    private var chatRoomStatusListeners: [String: ListenerRegistration] = [:]
    
    private init() {}
    
    // MARK: - Chat Room Management
    
    /// Creates a new chat room for a swipe request
    /// - Parameters:
    ///   - request: The SwipeRequest to create a chat room for
    /// - Returns: The created ChatRoom, or nil if creation failed
    func createChatRoom(for request: SwipeRequest) async -> ChatRoom? {
        guard let requestId = request.id else {
            errorMessage = "Invalid request data for chat room creation"
            return nil
        }
        
        // For open requests, swiperId might be empty - that's okay
        let swiperId = request.swiperId.isEmpty ? "" : request.swiperId
        
        let chatRoom = ChatRoom(
            requestId: requestId,
            requesterId: request.requesterId,
            swiperId: swiperId
        )
        
        do {
            // Use the request ID as the chat room document ID
            try db.collection("chatRooms").document(requestId).setData(from: chatRoom)
            
            // Add initial system message only if there's a swiper
            if !swiperId.isEmpty, let swiperName = await getSwiperName(swiperId: swiperId) {
                let systemMessage = ChatMessage.requestAccepted(
                    chatRoomId: requestId,
                    swiperName: swiperName
                )
                await sendMessage(systemMessage)
            } else if swiperId.isEmpty {
                // For open requests, add a different initial message
                let systemMessage = ChatMessage.createSystemMessage(
                    chatRoomId: requestId,
                    content: "Chat room created for your swipe request"
                )
                await sendMessage(systemMessage)
            }
            
            print("Chat room created successfully for request: \(requestId)")
            return chatRoom
            
        } catch {
            errorMessage = "Failed to create chat room: \(error.localizedDescription)"
            print("Error creating chat room: \(error)")
            return nil
        }
    }
    
    /// Updates the swiper in an existing chat room when someone new accepts the request
    /// - Parameters:
    ///   - requestId: The ID of the request
    ///   - newSwiperId: The ID of the new swiper
    func updateChatRoomSwiper(requestId: String, newSwiperId: String) async {
        do {
            // Update the swiper in the chat room
            let updateData: [String: Any] = [
                "swiperId": newSwiperId,
                "lastMessageAt": Timestamp()
            ]
            try await db.collection("chatRooms").document(requestId).updateData(updateData)
            
            // Add system message about the change
            if let swiperName = await getSwiperName(swiperId: newSwiperId) {
                let systemMessage = ChatMessage.swiperChanged(
                    chatRoomId: requestId,
                    newSwiperName: swiperName
                )
                await sendMessage(systemMessage)
            }
            
            print("Chat room swiper updated for request: \(requestId)")
            
        } catch {
            errorMessage = "Failed to update chat room swiper: \(error.localizedDescription)"
            print("Error updating chat room swiper: \(error)")
        }
    }
    
    /// Gets a chat room for a specific request
    /// - Parameter requestId: The ID of the request
    /// - Returns: The ChatRoom if it exists, nil otherwise
    func getChatRoom(for requestId: String) async -> ChatRoom? {
        do {
            let document = try await db.collection("chatRooms").document(requestId).getDocument()
            return try document.data(as: ChatRoom.self)
        } catch {
            print("Error fetching chat room: \(error)")
            return nil
        }
    }
    
    // MARK: - Message Management
    
    /// Sends a user message to a chat room
    /// - Parameters:
    ///   - content: The message content
    ///   - chatRoomId: The ID of the chat room
    func sendUserMessage(content: String, to chatRoomId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Cannot send empty message or user not authenticated"
            return
        }
        
        let message = ChatMessage(
            chatRoomId: chatRoomId,
            senderId: currentUserId,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            messageType: .userMessage
        )
        
        await sendMessage(message)
    }
    
    /// Sends a system notification message to a chat room
    /// - Parameters:
    ///   - content: The system message content
    ///   - chatRoomId: The ID of the chat room
    func sendSystemMessage(content: String, to chatRoomId: String) async {
        let systemMessage = ChatMessage.createSystemMessage(
            chatRoomId: chatRoomId,
            content: content
        )
        await sendMessage(systemMessage)
    }
    
    /// Internal method to send any type of message
    /// - Parameter message: The ChatMessage to send
    private func sendMessage(_ message: ChatMessage) async {
        do {
            // Add message to the messages subcollection
            try db.collection("chatRooms")
                .document(message.chatRoomId)
                .collection("messages")
                .addDocument(from: message)
            
            // Update the chat room's last message info
            let updateData: [String: Any] = [
                "lastMessage": message.content,
                "lastMessageAt": message.timestamp
            ]
            try await db.collection("chatRooms").document(message.chatRoomId).updateData(updateData)
            
            print("Message sent successfully to chat room: \(message.chatRoomId)")
            
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            print("Error sending message: \(error)")
        }
    }
    
    // MARK: - System Message Helpers for Request Status Changes
    
    /// Sends system message when request is cancelled
    func sendRequestCancelledMessage(requestId: String, cancelledByUserId: String) async {
        let userName = await getUserName(userId: cancelledByUserId)
        let systemMessage = ChatMessage.requestCancelled(
            chatRoomId: requestId,
            cancelledBy: userName
        )
        await sendMessage(systemMessage)
        
    }
    
    /// Sends system message when request goes in progress
    func sendRequestInProgressMessage(requestId: String) async {
        let systemMessage = ChatMessage.requestInProgress(chatRoomId: requestId)
        await sendMessage(systemMessage)
    }
    
    /// Sends system message when request is awaiting review
    func sendRequestAwaitingReviewMessage(requestId: String) async {
        let systemMessage = ChatMessage.requestAwaitingReview(chatRoomId: requestId)
        await sendMessage(systemMessage)
    }
    
    /// Sends system message when request is completed
    func sendRequestCompletedMessage(requestId: String) async {
        let systemMessage = ChatMessage.requestCompleted(chatRoomId: requestId)
        await sendMessage(systemMessage)
    }
    
    /// Closes a chat room when request is cancelled
    func closeChatRoom(requestId: String) async {
        do {
            // Mark chat room as inactive
            let updateData: [String: Any] = [
                "isActive": false,
                "lastMessageAt": Timestamp()
            ]
            try await db.collection("chatRooms").document(requestId).updateData(updateData)
            
            // Add system message about chat closure
            let systemMessage = ChatMessage.chatClosed(chatRoomId: requestId)
            await sendMessage(systemMessage)
            
            print("Chat room closed for request: \(requestId)")
            
        } catch {
            errorMessage = "Failed to close chat room: \(error.localizedDescription)"
            print("Error closing chat room: \(error)")
        }
    }
    
    // MARK: - Real-time Listeners
    
    /// Starts listening for real-time updates in a chat room
    /// - Parameters:
    ///   - chatRoomId: The ID of the chat room to listen to
    ///   - completion: Callback with the updated messages
    func startListeningToMessages(
        in chatRoomId: String,
        completion: @escaping ([ChatMessage]) -> Void
    ) {
        // Remove existing listener if any
        stopListeningToMessages(in: chatRoomId)
        
        let listener = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error listening to messages: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    completion([])
                    return
                }
                
                let messages = documents.compactMap { document in
                    try? document.data(as: ChatMessage.self)
                }
                
                completion(messages)
            }
        
        chatRoomListeners[chatRoomId] = listener
    }
    
    /// Stops listening to messages in a specific chat room
    /// - Parameter chatRoomId: The ID of the chat room to stop listening to
    func stopListeningToMessages(in chatRoomId: String) {
        chatRoomListeners[chatRoomId]?.remove()
        chatRoomListeners.removeValue(forKey: chatRoomId)
    }
    
    /// Starts listening for real-time updates to a chat room's status
    /// - Parameters:
    ///   - chatRoomId: The ID of the chat room to listen to
    ///   - completion: Callback with the chat room's active status
    func startListeningToChatRoomStatus(
        in chatRoomId: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Remove existing listener if any
        stopListeningToChatRoomStatus(in: chatRoomId)
        
        let listener = db.collection("chatRooms")
            .document(chatRoomId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    print("Error listening to chat room status: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let isActive = data["isActive"] as? Bool else {
                    completion(true) // Default to active if we can't determine status
                    return
                }
                
                completion(isActive)
            }
        
        chatRoomStatusListeners[chatRoomId] = listener
    }
    
    /// Stops listening to chat room status in a specific chat room
    /// - Parameter chatRoomId: The ID of the chat room to stop listening to
    func stopListeningToChatRoomStatus(in chatRoomId: String) {
        chatRoomStatusListeners[chatRoomId]?.remove()
        chatRoomStatusListeners.removeValue(forKey: chatRoomId)
    }
    
    /// Stops all active listeners
    func stopAllListeners() {
        for (_, listener) in chatRoomListeners {
            listener.remove()
        }
        chatRoomListeners.removeAll()
        
        for (_, listener) in chatRoomStatusListeners {
            listener.remove()
        }
        chatRoomStatusListeners.removeAll()
    }
    
    // MARK: - Helper Methods
    
    /// Gets the display name for a user
    /// - Parameter userId: The user ID
    /// - Returns: The user's display name or "Unknown User" if not found
    private func getUserName(userId: String) async -> String {
        if let user = await userManager.getUser(userId: userId) {
            return "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
        }
        return "Unknown User"
    }
    
    /// Gets the swiper's name for system messages
    /// - Parameter swiperId: The swiper's user ID
    /// - Returns: The swiper's display name
    private func getSwiperName(swiperId: String) async -> String? {
        return await getUserName(userId: swiperId)
    }
    
    /// Checks if the current user is a participant in the chat room
    /// - Parameter chatRoom: The ChatRoom to check
    /// - Returns: True if the current user is a participant, false otherwise
    func isParticipant(in chatRoom: ChatRoom) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return chatRoom.isParticipant(userId: currentUserId)
    }
    
    /// Gets the other participant's user info for display
    /// - Parameter chatRoom: The ChatRoom
    /// - Returns: The other participant's user ID
    func getOtherParticipantId(in chatRoom: ChatRoom) -> String? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        return chatRoom.getOtherParticipantId(currentUserId: currentUserId)
    }
}
