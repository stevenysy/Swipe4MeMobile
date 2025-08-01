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
    var userUnreadCounts: UserUnreadCounts?  // Current user's unread counts
    private var chatRoomListeners: [String: ListenerRegistration] = [:]
    private var chatRoomStatusListeners: [String: ListenerRegistration] = [:]
    private var proposalStatusListeners: [String: ListenerRegistration] = [:]
    private var unreadCountListener: ListenerRegistration?
    
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
            
            // Add initial system message based on request status
            if !swiperId.isEmpty, let swiperName = await getSwiperName(swiperId: swiperId) {
                // If there's a swiper, this is an acceptance
                let systemMessage = ChatMessage.requestAccepted(
                    chatRoomId: requestId,
                    swiperName: swiperName
                )
                await sendMessage(systemMessage)
            } else {
                // For new open requests, add a welcome message
                let systemMessage = ChatMessage.createSystemMessage(
                    chatRoomId: requestId,
                    content: "Chat room created! When someone accepts your request, you can chat here."
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
    
    /// Sends an interactive proposal message to a chat room
    /// - Parameters:
    ///   - requestId: The ID of the request/chat room
    ///   - proposalId: The ID of the change proposal
    ///   - proposerId: User ID of who proposed the change
    ///   - changesDescription: Description of the proposed changes
    func sendProposalMessage(
        requestId: String,
        proposalId: String,
        proposerId: String,
        changesDescription: String
    ) async {
        let proposalMessage = ChatMessage.createProposalMessage(
            chatRoomId: requestId,
            proposalId: proposalId,
            proposerId: proposerId,
            changesDescription: changesDescription
        )
        await sendMessage(proposalMessage)
    }
    
    // MARK: - Proposal Response Management
    
    /// Accepts a change proposal and applies the changes
    /// - Parameters:
    ///   - proposalId: The ID of the proposal to accept
    ///   - responderId: The user ID of who is accepting
    func acceptProposal(proposalId: String, responderId: String) async {
        do {
            // Update proposal status to accepted
            let updateData: [String: Any] = [
                "status": "accepted",
                "respondedAt": Timestamp(),
                "respondedById": responderId
            ]
            try await db.collection("changeProposals").document(proposalId).updateData(updateData)
            
            // Get the proposal and original request
            guard let proposal = await getProposal(proposalId: proposalId),
                  let originalRequest = await getSwipeRequest(requestId: proposal.requestId) else {
                errorMessage = "Failed to get proposal or request data"
                return
            }
            
            // Apply the changes to the original request
            await applyProposalChanges(proposal: proposal, to: originalRequest)
            
            // Send acceptance message
            let responderName = await getUserName(userId: responderId)
            let changesDescription = proposal.getChangesDescription(comparedTo: originalRequest)
            let acceptMessage = ChatMessage.proposalAccepted(
                chatRoomId: proposal.requestId,
                responderId: responderId,
                acceptedBy: responderName,
                changesDescription: changesDescription
            )
            await sendMessage(acceptMessage)
            
        } catch {
            errorMessage = "Failed to accept proposal: \(error.localizedDescription)"
            print("Error accepting proposal: \(error)")
        }
    }
    
    /// Declines a change proposal
    /// - Parameters:
    ///   - proposalId: The ID of the proposal to decline
    ///   - responderId: The user ID of who is declining
    func declineProposal(proposalId: String, responderId: String) async {
        do {
            // Update proposal status to declined
            let updateData: [String: Any] = [
                "status": "declined",
                "respondedAt": Timestamp(),
                "respondedById": responderId
            ]
            try await db.collection("changeProposals").document(proposalId).updateData(updateData)
            
            // Get proposal for messaging
            guard let proposal = await getProposal(proposalId: proposalId) else {
                errorMessage = "Failed to get proposal data"
                return
            }
            
            // Send decline message
            let responderName = await getUserName(userId: responderId)
            let declineMessage = ChatMessage.proposalDeclined(
                chatRoomId: proposal.requestId,
                responderId: responderId,
                declinedBy: responderName
            )
            await sendMessage(declineMessage)
            
        } catch {
            errorMessage = "Failed to decline proposal: \(error.localizedDescription)"
            print("Error declining proposal: \(error)")
        }
    }
    
    /// Applies approved proposal changes to the original request
    /// - Parameters:
    ///   - proposal: The approved ChangeProposal
    ///   - originalRequest: The original SwipeRequest to update
    private func applyProposalChanges(proposal: ChangeProposal, to originalRequest: SwipeRequest) async {
        do {
            var updatedRequest = originalRequest
            let meetingTimeChanged = proposal.proposedMeetingTime != nil && 
                                   proposal.proposedMeetingTime != originalRequest.meetingTime
            
            // Apply location change if proposed
            if let proposedLocation = proposal.proposedLocation {
                updatedRequest.location = proposedLocation
            }
            
            // Apply meeting time change if proposed
            if let proposedMeetingTime = proposal.proposedMeetingTime {
                updatedRequest.meetingTime = proposedMeetingTime
            }
            
            // Handle Cloud Task rescheduling if meeting time changed for scheduled requests
            if meetingTimeChanged && originalRequest.status == .scheduled {
                await SwipeRequestManager.shared.rescheduleCloudTasks(from: originalRequest, to: updatedRequest)
            } else {
                // No meeting time change or not a scheduled request - simple update
                guard let requestId = updatedRequest.id else {
                    errorMessage = "Invalid request ID for applying changes"
                    return
                }
                
                try db.collection("swipeRequests").document(requestId).setData(from: updatedRequest)
            }
            
            print("Applied proposal changes to request: \(updatedRequest.id ?? "unknown")")
            
        } catch {
            errorMessage = "Failed to apply proposal changes: \(error.localizedDescription)"
            print("Error applying proposal changes: \(error)")
        }
    }
    
    // MARK: - Helper Methods for Proposals
    
    /// Gets a ChangeProposal by ID
    /// - Parameter proposalId: The proposal ID
    /// - Returns: The ChangeProposal if found
    func getProposal(proposalId: String) async -> ChangeProposal? {
        do {
            let document = try await db.collection("changeProposals").document(proposalId).getDocument()
            return try document.data(as: ChangeProposal.self)
        } catch {
            print("Error fetching proposal: \(error)")
            return nil
        }
    }
    
    /// Gets a SwipeRequest by ID
    /// - Parameter requestId: The request ID
    /// - Returns: The SwipeRequest if found
    private func getSwipeRequest(requestId: String) async -> SwipeRequest? {
        do {
            let document = try await db.collection("swipeRequests").document(requestId).getDocument()
            return try document.data(as: SwipeRequest.self)
        } catch {
            print("Error fetching swipe request: \(error)")
            return nil
        }
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
            
            // Increment unread count for recipient if message type requires it
            if message.messageType.shouldIncrementUnreadCount,
               let currentUserId = Auth.auth().currentUser?.uid,
               let chatRoom = await getChatRoom(for: message.chatRoomId),
               let recipientId = chatRoom.getOtherParticipantId(currentUserId: currentUserId) {
                
                await incrementUnreadCount(for: recipientId, in: message.chatRoomId)
            }
            
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
    
    /// Sends interactive review request message when request is awaiting review
    func sendReviewRequestMessage(requestId: String) async {
        let reviewMessage = ChatMessage.createReviewRequestMessage(chatRoomId: requestId)
        await sendMessage(reviewMessage)
    }
    
    /// Sends confirmation message when a review is submitted
    func sendReviewSubmittedMessage(requestId: String, reviewerUserId: String) async {
        let reviewerName = await getUserName(userId: reviewerUserId)
        let confirmationMessage = ChatMessage.reviewSubmitted(chatRoomId: requestId, reviewerName: reviewerName)
        await sendMessage(confirmationMessage)
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
    
    /// Starts listening for real-time updates to a proposal's status
    /// - Parameters:
    ///   - proposalId: The ID of the proposal to listen to
    ///   - completion: Callback with the updated proposal status
    func startListeningToProposalStatus(
        proposalId: String,
        completion: @escaping (ProposalStatus) -> Void
    ) {
        // Remove existing listener if any
        stopListeningToProposalStatus(proposalId: proposalId)
        
        let listener = db.collection("changeProposals")
            .document(proposalId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    print("Error listening to proposal status: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let statusString = data["status"] as? String,
                      let status = ProposalStatus(rawValue: statusString) else {
                    return
                }
                
                completion(status)
            }
        
        proposalStatusListeners[proposalId] = listener
    }
    
    /// Stops listening to proposal status for a specific proposal
    /// - Parameter proposalId: The ID of the proposal to stop listening to
    func stopListeningToProposalStatus(proposalId: String) {
        proposalStatusListeners[proposalId]?.remove()
        proposalStatusListeners.removeValue(forKey: proposalId)
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
        
        for (_, listener) in proposalStatusListeners {
            listener.remove()
        }
        proposalStatusListeners.removeAll()
        
        stopListeningToUnreadCounts()
    }
    
    // MARK: - Unread Counts Management
    
    /// Starts listening for unread count changes for the current user
    func startListeningToUnreadCounts() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No authenticated user to listen for unread counts")
            return
        }
        
        // Stop existing listener if any
        stopListeningToUnreadCounts()
        
        // Listen to the user's unread counts document
        unreadCountListener = db.collection("userUnreadCounts")
            .document(currentUserId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                if let error = error {
                    print("Error listening to unread counts: \(error)")
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    do {
                        let unreadCounts = try document.data(as: UserUnreadCounts.self)
                        self?.userUnreadCounts = unreadCounts
                    } catch {
                        print("Error decoding unread counts: \(error)")
                    }
                } else {
                    // Document doesn't exist, create empty one
                    self?.userUnreadCounts = UserUnreadCounts(userId: currentUserId)
                }
            }
    }
    
    /// Stops listening to unread count changes
    func stopListeningToUnreadCounts() {
        unreadCountListener?.remove()
        unreadCountListener = nil
    }
    
    /// Resets unread count to 0 for the current user in a specific chat room
    /// - Parameter chatRoomId: The ID of the chat room
    func resetUnreadCount(for chatRoomId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No authenticated user to reset unread count")
            return
        }
        
        do {
            // Get current document to preserve other chat room counts
            let document = try await db.collection("userUnreadCounts").document(currentUserId).getDocument()
            var chatRoomCounts: [String: Int] = [:]
            
            if document.exists,
               let data = document.data(),
               let existingCounts = data["chatRoomCounts"] as? [String: Int] {
                chatRoomCounts = existingCounts
            }
            
            // Update the specific chat room count
            chatRoomCounts[chatRoomId] = 0
            
            let updateData: [String: Any] = [
                "chatRoomCounts": chatRoomCounts,
                "lastUpdated": Timestamp()
            ]
            try await db.collection("userUnreadCounts").document(currentUserId).setData(updateData, merge: true)
            print("Unread count reset for user \(currentUserId) in chat room \(chatRoomId)")
        } catch {
            errorMessage = "Failed to reset unread count: \(error.localizedDescription)"
            print("Error resetting unread count: \(error)")
        }
    }
    
    /// Increments unread count for a specific user in a specific chat room
    /// - Parameters:
    ///   - userId: The user ID to increment count for
    ///   - chatRoomId: The chat room ID
    private func incrementUnreadCount(for userId: String, in chatRoomId: String) async {
        do {
            // Get current document to preserve other chat room counts
            let document = try await db.collection("userUnreadCounts").document(userId).getDocument()
            var chatRoomCounts: [String: Int] = [:]
            
            if document.exists,
               let data = document.data(),
               let existingCounts = data["chatRoomCounts"] as? [String: Int] {
                chatRoomCounts = existingCounts
            }
            
            // Increment the specific chat room count
            let currentCount = chatRoomCounts[chatRoomId] ?? 0
            chatRoomCounts[chatRoomId] = currentCount + 1
            
            let updateData: [String: Any] = [
                "chatRoomCounts": chatRoomCounts,
                "lastUpdated": Timestamp()
            ]
            try await db.collection("userUnreadCounts").document(userId).setData(updateData, merge: true)
            print("Unread count incremented for user \(userId) in chat room \(chatRoomId)")
        } catch {
            print("Error incrementing unread count: \(error)")
        }
    }
    
    /// Gets the unread count for a specific chat room from cached data
    /// - Parameter chatRoomId: The ID of the chat room
    /// - Returns: The unread count for the current user in that chat room
    func getUnreadCount(for chatRoomId: String) -> Int {
        return userUnreadCounts?.getUnreadCount(for: chatRoomId) ?? 0
    }
    
    /// Gets total unread count across all chat rooms
    var totalUnreadCount: Int {
        return userUnreadCounts?.totalUnreadCount ?? 0
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
    
    // MARK: - Active Chat Tracking
    
    /// Sets the current user's active chat room
    /// - Parameter chatRoomId: The ID of the chat room the user is currently viewing
    func setActiveChat(_ chatRoomId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No authenticated user to set active chat")
            return
        }
        
        do {
            try await db.collection("users").document(currentUserId).setData([
                "activeChat": chatRoomId
            ], merge: true)
            print("Active chat set to: \(chatRoomId)")
        } catch {
            print("Error setting active chat: \(error)")
        }
    }
    
    /// Clears the current user's active chat room
    func clearActiveChat() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No authenticated user to clear active chat")
            return
        }
        
        do {
            try await db.collection("users").document(currentUserId).setData([
                "activeChat": FieldValue.delete()
            ], merge: true)
            print("Active chat cleared")
        } catch {
            print("Error clearing active chat: \(error)")
        }
    }
}
