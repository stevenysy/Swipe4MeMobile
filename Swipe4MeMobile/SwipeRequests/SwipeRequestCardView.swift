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
    var onDelete: () -> Void = {}
    var onEdit: () -> Void = {}
    var onSwiped: () -> Void = {}  // New action for "Swiped!" button
    var isRequesterCard: Bool = true  // true for requester requests, false for swiper requests

    @Environment(SnackbarManager.self) private var snackbarManager
    @State private var isEditing = false
    @State private var editedLocation: DiningLocation = .commons  // Default, updated on edit
    @State private var editedMeetingTime = Date()

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
        onEdit()
    }

    private func handleDelete() {
        print("deleting swipe request with id \(String(describing: request.id))")
        onDelete()
    }
    
    private func handleSwiped() {
        print("marking request as swiped: \(String(describing: request.id))")
        onSwiped()
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
            // Note: No edit button for in-progress requests
            
            Button("Delete", role: .destructive) {
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

            Button("Delete", role: .destructive) {
                onDelete()
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
//                onDelete: {
//                    print("Delete action triggered for open request: \(openRequest.id ?? "N/A")")
//                }, 
//                onEdit: {
//                    print("Edit submitted for open request: \(openRequest.id ?? "N/A")")
//                }, 
//                isRequesterCard: true
//            )
//            
//            // In-progress request (requester view - shows "Swiped!" button)
//            SwipeRequestCardView(
//                request: inProgressRequestCopy, 
//                isExpanded: true, 
//                onDelete: {
//                    print("Delete action triggered for in-progress request: \(inProgressRequestCopy.id ?? "N/A")")
//                }, 
//                onSwiped: {
//                    print("Swiped action triggered for request: \(inProgressRequestCopy.id ?? "N/A")")
//                },
//                isRequesterCard: true
//            )
//            
//            // In-progress request (swiper view - no "Swiped!" button)
//            SwipeRequestCardView(
//                request: inProgressRequestCopy, 
//                isExpanded: true, 
//                onDelete: {
//                    print("Delete action triggered for swiper in-progress request: \(inProgressRequestCopy.id ?? "N/A")")
//                }, 
//                isRequesterCard: false
//            )
//        }
//    }
//    .padding()
//    .background(Color(.systemGroupedBackground))
//    .environment(SnackbarManager())
}
