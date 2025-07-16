//
//  SwipeRequestCardViewModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import FirebaseFirestore
import SwiftUI

@Observable
@MainActor
final class SwipeRequestCardViewModel {
    // MARK: - Published Properties
    var isEditing = false
    var editedLocation: DiningLocation = .commons
    var editedMeetingTime = Date()
    var requestToCancel: SwipeRequest?
    var requestToMarkSwiped: SwipeRequest?
    var chatDestination: ChatDestination?
    
    // MARK: - Dependencies
    private let swipeRequestManager = SwipeRequestManager.shared
    private let snackbarManager = SnackbarManager.shared
    private let userManager = UserManager.shared
    private let chatManager = ChatManager.shared
    
    // MARK: - Computed Properties
    
    /// Gets the unread count for a specific request's chat room
    func getUnreadCount(for request: SwipeRequest) -> Int {
        guard let requestId = request.id else { 
            return 0 
        }
        return chatManager.getUnreadCount(for: requestId)
    }
    
    // MARK: - Public Methods
    func handleEdit(for request: SwipeRequest) {
        editedLocation = request.location
        editedMeetingTime = request.meetingTime.dateValue()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = true
        }
    }
    
    func handleSubmit(for request: SwipeRequest) {
        // Check if this requires approval from the other party
        if request.status.requiresApprovalForChanges {
            // Create a change proposal instead of direct update
            createChangeProposal(for: request)
        } else {
            // Direct update for open requests
            performDirectUpdate(for: request)
        }
    }
    
    func handleDelete(for request: SwipeRequest) {
        requestToCancel = request
    }
    
    func handleSwiped(for request: SwipeRequest) {
        requestToMarkSwiped = request
    }
    
    func handleChatTap(for request: SwipeRequest) {
        Task {
            await openChat(for: request)
        }
    }
    
    func confirmCancel() {
        guard let request = requestToCancel else { return }
        
        // Determine if current user is the swiper
        let currentUserId = UserManager.shared.userID
        let isSwiper = currentUserId == request.swiperId
        
        if isSwiper {
            swipeRequestManager.cancelRequestAsSwiper(request: request)
            let message = request.status == .scheduled ? "Removed from request - it's now open again" : "Request Cancelled"
            snackbarManager.show(title: message, style: .success)
        } else {
            swipeRequestManager.cancelRequest(request: request)
            snackbarManager.show(title: "Request Cancelled", style: .success)
            
            // Close the chat room when requester cancels (complete cancellation)
            if let requestId = request.id {
                Task {
                    await chatManager.closeChatRoom(requestId: requestId)
                }
            }
        }
        
        requestToCancel = nil
    }
    
    func cancelDelete() {
        requestToCancel = nil
    }
    
    func confirmSwiped() {
        guard let request = requestToMarkSwiped else { return }
        swipeRequestManager.markRequestAsSwiped(request: request)
        snackbarManager.show(title: "Marked as Swiped!", style: .success)
        requestToMarkSwiped = nil
    }
    
    func cancelSwiped() {
        requestToMarkSwiped = nil
    }
    
    func cancelEditing() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = false
        }
    }
    
    // MARK: - Change Proposal Methods
    
    private func createChangeProposal(for request: SwipeRequest) {
        let currentUserId = UserManager.shared.userID
        
        Task {
            do {
                // Create the proposal in database
                let proposalId = try await swipeRequestManager.createChangeProposal(
                    for: request,
                    proposedLocation: editedLocation != request.location ? editedLocation : nil,
                    proposedMeetingTime: Timestamp(date: editedMeetingTime) != request.meetingTime ? Timestamp(date: editedMeetingTime) : nil,
                    proposedById: currentUserId
                )
                
                // Get user info and send chat message
                guard let proposerUser = await UserManager.shared.getUser(userId: currentUserId) else {
                    throw CloudTaskError.invalidResponse
                }
                
                let proposerName = "\(proposerUser.firstName) \(proposerUser.lastName)".trimmingCharacters(in: .whitespaces)
                
                // Create proposal with the changes for description
                let proposal = ChangeProposal(
                    requestId: request.id!,
                    proposedById: currentUserId,
                    proposedLocation: editedLocation != request.location ? editedLocation : nil,
                    proposedMeetingTime: Timestamp(date: editedMeetingTime) != request.meetingTime ? Timestamp(date: editedMeetingTime) : nil
                )
                let changesDescription = proposal.getChangesDescription(comparedTo: request)
                
                // Send proposal message to chat
                await chatManager.sendProposalMessage(
                    requestId: request.id!,
                    proposalId: proposalId,
                    proposerName: proposerName,
                    changesDescription: changesDescription
                )
                
                snackbarManager.show(title: "Change proposal sent", style: .success)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isEditing = false
                }
            } catch {
                if error.localizedDescription.contains("invalidResponse") {
                    snackbarManager.show(title: "No changes detected", style: .info)
                } else {
                    snackbarManager.show(title: "Failed to create proposal: \(error.localizedDescription)", style: .error)
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isEditing = false
                }
            }
        }
    }

    
    private func performDirectUpdate(for request: SwipeRequest) {
        var updatedRequest = request
        updatedRequest.location = editedLocation
        updatedRequest.meetingTime = Timestamp(date: editedMeetingTime)
        
        swipeRequestManager.addSwipeRequestToDatabase(
            swipeRequest: updatedRequest, isEdit: true)
        snackbarManager.show(title: "Request Updated", style: .success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = false
        }
    }
    
    // MARK: - Chat Navigation
    
    private func openChat(for request: SwipeRequest) async {
        guard let requestId = request.id else {
            snackbarManager.show(title: "Cannot open chat: Invalid request", style: .error)
            return
        }
        
        // Get or create chat room
        var chatRoom: ChatRoom?
        
        // Get existing chat room (should always exist now since we create them upfront)
        chatRoom = await chatManager.getChatRoom(for: requestId)
        
        // If no chat room exists, create one (fallback for older requests)
        if chatRoom == nil {
            chatRoom = await chatManager.createChatRoom(for: request)
        }
        
        guard let finalChatRoom = chatRoom else {
            snackbarManager.show(title: "Unable to access chat", style: .error)
            return
        }
        
        // Set the navigation destination
        chatDestination = ChatDestination(chatRoom: finalChatRoom, swipeRequest: request)
    }
}

// MARK: - Chat Navigation Helper

struct ChatDestination: Identifiable {
    let id = UUID()
    let chatRoom: ChatRoom
    let swipeRequest: SwipeRequest
} 