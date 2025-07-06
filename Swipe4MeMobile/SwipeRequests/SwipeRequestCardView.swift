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

    @Environment(SnackbarManager.self) private var snackbarManager
    @State private var isEditing = false
    @State private var editedLocation: DiningLocation = .commons
    @State private var editedMeetingTime = Date()
    @State private var requestToCancel: SwipeRequest?
    @State private var requestToMarkSwiped: SwipeRequest?

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

                StatusPillView(status: request.status)
            }

            if isExpanded {
                if isEditing {
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
            "Cancel Request", isPresented: .constant(requestToCancel != nil),
            presenting: requestToCancel
        ) { request in
            Button("Cancel Request", role: .destructive) {
                SwipeRequestManager.shared.cancelRequest(request: request)
                snackbarManager.show(title: "Request Cancelled", style: .success)
                requestToCancel = nil
            }
            Button("Keep Request", role: .cancel) {
                requestToCancel = nil
            }
        } message: { request in
            Text(
                "Are you sure you want to cancel this swipe request for \(request.location.rawValue) at \(request.meetingTime.dateValue(), style: .time)? This action cannot be undone."
            )
        }
        .alert(
            "Confirm Swipe Received", isPresented: .constant(requestToMarkSwiped != nil),
            presenting: requestToMarkSwiped
        ) { request in
            Button("Yes, I got it!", role: .none) {
                SwipeRequestManager.shared.markRequestAsSwiped(request: request)
                snackbarManager.show(title: "Marked as Swiped!", style: .success)
                requestToMarkSwiped = nil
            }
            Button("Not yet", role: .cancel) {
                requestToMarkSwiped = nil
            }
        } message: { request in
            Text(
                "Have you already received your swipe from the swiper for \(request.location.rawValue)?"
            )
        }
    }

    private func handleEdit() {
        editedLocation = request.location
        editedMeetingTime = request.meetingTime.dateValue()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = true
        }
    }

    private func handleSubmit() {
        var updatedRequest = request
        updatedRequest.location = editedLocation
        updatedRequest.meetingTime = Timestamp(date: editedMeetingTime)

        SwipeRequestManager.shared.addSwipeRequestToDatabase(
            swipeRequest: updatedRequest, isEdit: true)
        snackbarManager.show(title: "Request Updated", style: .success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = false
        }
    }

    private func handleDelete() {
        requestToCancel = request
    }
    
    private func handleSwiped() {
        requestToMarkSwiped = request
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
                    handleSwiped()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            
            Button("Cancel", role: .destructive) {
                handleDelete()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var defaultActionButtons: some View {
        HStack {
            Button("Edit") {
                handleEdit()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("Cancel", role: .destructive) {
                handleDelete()
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
                Picker("", selection: $editedLocation) {
                    ForEach(DiningLocation.allCases) { location in
                        Text(location.rawValue).tag(location)
                    }
                }
            }
            .pickerStyle(.menu)

            DatePicker(
                "Meeting Time",
                selection: $editedMeetingTime,
                in: Date()...
            )
        }
        .fontWeight(.semibold)

        HStack {
            Button("Cancel", role: .cancel) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isEditing = false
                }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("Submit") {
                handleSubmit()
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
