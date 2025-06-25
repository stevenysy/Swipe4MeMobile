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

    @ViewBuilder
    private var readOnlyStateView: some View {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
            Text("Swiper:")
                .font(.headline)
        }

                UserInfoView(userId: request.swiperId)

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
    VStack(spacing: 20) {
        if let request = SwipeRequest.mockRequests.first {
            SwipeRequestCardView(request: request, isExpanded: false)
            SwipeRequestCardView(
                request: request, isExpanded: true,
                onDelete: {
                    print("Delete action triggered for request: \(request.id ?? "N/A")")
                },
                onEdit: {
                    print("Edit submitted for request: \(request.id ?? "N/A")")
                })
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .environment(SnackbarManager())
}
