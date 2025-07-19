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
    
    // MARK: - Dependencies
    private let chatManager = ChatManager.shared
    private let userManager = UserManager.shared
    
    // MARK: - Initialization
    
    init(message: ChatMessage) {
        self.message = message
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