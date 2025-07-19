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
    
    @State private var viewModel: ChatConversationViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(chatRoom: ChatRoom, swipeRequest: SwipeRequest) {
        self.chatRoom = chatRoom
        self.swipeRequest = swipeRequest
        self._viewModel = State(initialValue: ChatConversationViewModel(chatRoom: chatRoom, swipeRequest: swipeRequest))
    }
    
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
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
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
            if let otherUserId = viewModel.otherParticipantId {
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
        if viewModel.isLoading {
            Spacer()
            ProgressView("Loading messages...")
                .foregroundColor(.secondary)
            Spacer()
        } else if viewModel.messages.isEmpty {
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
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: viewModel.isCurrentUserMessage(message)
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
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Auto-scroll to bottom when new messages arrive
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Instantly show latest messages when entering chat
                    if let lastMessage = viewModel.messages.last {
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
            if viewModel.isChatActive {
                // Text Input
                TextField("Type a message...", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                // Send Button
                Button(action: viewModel.sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.canSendMessage ? .blue : .gray)
                }
                .disabled(!viewModel.canSendMessage)
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

}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    @State private var viewModel: MessageBubbleViewModel
    
    init(message: ChatMessage, isCurrentUser: Bool) {
        self.message = message
        self.isCurrentUser = isCurrentUser
        self._viewModel = State(initialValue: MessageBubbleViewModel(message: message))
    }
    
    var body: some View {
        if message.messageType.isSystemMessage {
            // System messages centered with no spacing constraints
            HStack {
                Spacer()
                systemMessageView
                Spacer()
            }
        } else if message.messageType == .changeProposal {
            // Change proposals follow same positioning as regular messages but with card style
            HStack {
                if isCurrentUser {
                    Spacer(minLength: 50)
                }
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    ChangeProposalCardView(
                        message: message,
                        isCurrentUser: isCurrentUser,
                        viewModel: viewModel
                    )
                    .onAppear {
                        viewModel.onAppear()
                    }
                    .onDisappear {
                        viewModel.onDisappear()
                    }
                    
                    // Timestamp for proposal messages
                    Text(message.timestamp.dateValue().chatTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !isCurrentUser {
                    Spacer(minLength: 50)
                }
            }
        } else {
            // User messages with normal bubble layout
            HStack {
                if isCurrentUser {
                    Spacer(minLength: 50)
                }
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    userMessageView
                    
                    // Timestamp for user messages
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
        VStack(spacing: 8) {
            // Timestamp centered above the message
            Text(message.timestamp.dateValue().chatTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Regular system message as plain text
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

// MARK: - Change Proposal Card View

struct ChangeProposalCardView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let viewModel: MessageBubbleViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status indicator
            HStack {
                Image(systemName: "pencil.and.scribble")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Change Proposal")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let status = viewModel.proposalStatus {
                    StatusBadge(status: status)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
                         // Proposal content
             VStack(alignment: .leading, spacing: 12) {
                 Text(message.content)
                     .font(.body)
                     .foregroundColor(.primary)
                     .multilineTextAlignment(.leading)
                     .frame(maxWidth: .infinity, alignment: .leading)
             }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Action buttons (only show for recipient if proposal is still pending)
            if let proposalId = message.proposalId,
               !isCurrentUser, // Hide buttons for proposer
               viewModel.proposalStatus == .pending {
                
                Divider()
                    .padding(.horizontal, 16)
                
                HStack(spacing: 12) {
                    // Decline button
                    Button(action: {
                        viewModel.handleProposalAction(proposalId: proposalId, isAccept: false)
                    }) {
                        Text("Decline")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Accept button
                    Button(action: {
                        viewModel.handleProposalAction(proposalId: proposalId, isAccept: true)
                    }) {
                        Text("Accept")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            } else {
                // Add some bottom padding if no buttons are shown
                Spacer()
                    .frame(height: 16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ProposalStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Preview

//#Preview {
//    NavigationView {
//        ChatConversationView(
//            chatRoom: ChatRoom.mockChatRoom,
//            swipeRequest: SwipeRequest.mockRequests[0]
//        )
//    }
//} 

