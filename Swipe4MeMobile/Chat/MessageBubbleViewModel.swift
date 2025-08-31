//
//  MessageBubbleViewModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 1/2/25.
//

import SwiftUI

@Observable
@MainActor
final class MessageBubbleViewModel {
    // MARK: - Published Properties
    var proposalStatus: ProposalStatus? = nil
    
    // MARK: - Private Properties
    private let message: ChatMessage
    private let swipeRequest: SwipeRequest?
    
    // MARK: - Dependencies
    private let chatManager = ChatManager.shared
    private let userManager = UserManager.shared
    
    // MARK: - Initialization
    
    init(message: ChatMessage, swipeRequest: SwipeRequest? = nil) {
        self.message = message
        self.swipeRequest = swipeRequest
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if current user has completed their review of the other participant
    var reviewCompleted: Bool {
        guard let swipeRequest = swipeRequest,
              let currentUserId = userManager.currentUser?.id else { return false }
        
        // Check if current user has completed their review
        if currentUserId == swipeRequest.requesterId {
            return swipeRequest.requesterReviewCompleted
        } else if currentUserId == swipeRequest.swiperId {
            return swipeRequest.swiperReviewCompleted
        }
        
        return false
    }
    

    
    // MARK: - Public Methods
    
    func onAppear() {
        // Start listening to proposal status when view appears
        if let proposalId = message.proposalId {
            startListeningToProposalStatus(proposalId: proposalId)
        }
    }
    
    func onDisappear() {
        // Clean up listener when view disappears
        if let proposalId = message.proposalId {
            chatManager.stopListeningToProposalStatus(proposalId: proposalId)
        }
    }
    
    func handleProposalAction(proposalId: String, isAccept: Bool) {
        let currentUserId = userManager.userID
        
        Task {
            if isAccept {
                await chatManager.acceptProposal(proposalId: proposalId, responderId: currentUserId)
            } else {
                await chatManager.declineProposal(proposalId: proposalId, responderId: currentUserId)
            }
            // No need to manually refresh - the listener will handle it!
        }
    }
    
    // MARK: - Private Methods
    
    private func startListeningToProposalStatus(proposalId: String) {
        chatManager.startListeningToProposalStatus(proposalId: proposalId) { [weak self] status in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.proposalStatus = status
            }
        }
    }
} 