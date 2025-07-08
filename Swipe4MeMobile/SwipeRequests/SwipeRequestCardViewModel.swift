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
    
    // MARK: - Public Methods
    func handleEdit(for request: SwipeRequest) {
        editedLocation = request.location
        editedMeetingTime = request.meetingTime.dateValue()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = true
        }
    }
    
    func handleSubmit(for request: SwipeRequest) {
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
        let currentUserId = userManager.userID
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