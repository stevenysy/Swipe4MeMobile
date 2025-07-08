//
//  SwipeRequestCardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import FirebaseFirestore
import SwiftUI

struct SwipeRequestCardView: View {
    let request: SwipeRequest
    var isExpanded: Bool = false
    var isRequesterCard: Bool = true

    @State private var viewModel = SwipeRequestCardViewModel()
    
    // Show chat icon for statuses where chat is available
    private var shouldShowChatIcon: Bool {
        switch request.status {
        case .open, .scheduled, .inProgress, .awaitingReview:
            return true
        case .complete, .canceled:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(request.location.rawValue)
                        .font(.headline)
                    Text("Meeting at: \(request.meetingTime.dateValue(), style: .time)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                HStack(spacing: 8) {
                    // Chat Icon (only for certain statuses)
                    if shouldShowChatIcon {
                        Button(action: { viewModel.handleChatTap(for: request) }) {
                            Image(systemName: "message.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    StatusPillView(status: request.status)
                }
            }

            if isExpanded {
                if viewModel.isEditing {
                    editStateView
                } else {
                    readOnlyStateView
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .alert(
            "Cancel Request", isPresented: .constant(viewModel.requestToCancel != nil),
            presenting: viewModel.requestToCancel
        ) { request in
            Button("Cancel Request", role: .destructive) {
                viewModel.confirmCancel()
            }
            Button("Keep Request", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: { request in
            Text(
                "Are you sure you want to cancel this swipe request for \(request.location.rawValue) at \(request.meetingTime.dateValue(), style: .time)? This action cannot be undone."
            )
        }
        .alert(
            "Confirm Swipe Received", isPresented: .constant(viewModel.requestToMarkSwiped != nil),
            presenting: viewModel.requestToMarkSwiped
        ) { request in
            Button("Yes, I got it!", role: .none) {
                viewModel.confirmSwiped()
            }
            Button("Not yet", role: .cancel) {
                viewModel.cancelSwiped()
            }
        } message: { request in
            Text(
                "Have you already received your swipe from the swiper for \(request.location.rawValue)?"
            )
        }
        .sheet(item: $viewModel.chatDestination) { destination in
            NavigationView {
                ChatConversationView(
                    chatRoom: destination.chatRoom,
                    swipeRequest: destination.swipeRequest
                )
            }
        }
    }

    @ViewBuilder
    private var readOnlyStateView: some View {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
            Text(isRequesterCard ? "Swiper:" : "Requester:")
                .font(.headline)
        }

        if isRequesterCard {
            UserInfoView(userId: request.swiperId)
        } else {
            UserInfoView(userId: request.requesterId)
        }

        // Modular action buttons based on status and user role
        actionButtonsForStatus
    }
    
    @ViewBuilder
    private var actionButtonsForStatus: some View {
        switch request.status {
        case .inProgress:
            inProgressActionButtons
        default:
            defaultActionButtons
        }
    }
    
    @ViewBuilder
    private var inProgressActionButtons: some View {
        HStack {
            if isRequesterCard {
                Button("Swiped!") {
                    viewModel.handleSwiped(for: request)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            
            Button("Cancel", role: .destructive) {
                viewModel.handleDelete(for: request)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var defaultActionButtons: some View {
        HStack {
            Button("Edit") {
                viewModel.handleEdit(for: request)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("Cancel", role: .destructive) {
                viewModel.handleDelete(for: request)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var editStateView: some View {
        Divider()

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Location")
                Spacer()
                Picker("", selection: $viewModel.editedLocation) {
                    ForEach(DiningLocation.allCases) { location in
                        Text(location.rawValue).tag(location)
                    }
                }
            }
            .pickerStyle(.menu)

            DatePicker(
                "Meeting Time",
                selection: $viewModel.editedMeetingTime,
                in: Date()...
            )
        }
        .fontWeight(.semibold)

        HStack {
            Button("Cancel", role: .cancel) {
                viewModel.cancelEditing()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("Submit") {
                viewModel.handleSubmit(for: request)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
//    VStack(spacing: 20) {
//        if let openRequest = SwipeRequest.mockRequests.first,
//           let inProgressRequest = SwipeRequest.mockRequests.first {
//            
//            // Create an in-progress version for testing
//            var inProgressRequestCopy = inProgressRequest
//            inProgressRequestCopy.status = .inProgress
//            
//            // Open request (default behavior)
//            SwipeRequestCardView(
//                request: openRequest, 
//                isExpanded: true, 
//                isRequesterCard: true
//            )
//            
//            // In-progress request (requester view - shows "Swiped!" button)
//            SwipeRequestCardView(
//                request: inProgressRequestCopy, 
//                isExpanded: true, 
//                isRequesterCard: true
//            )
//            
//            // In-progress request (swiper view - no "Swiped!" button)
//            SwipeRequestCardView(
//                request: inProgressRequestCopy, 
//                isExpanded: true, 
//                isRequesterCard: false
//            )
//        }
//    }
//    .padding()
//    .background(Color(.systemGroupedBackground))
//    .environment(SnackbarManager())
}
