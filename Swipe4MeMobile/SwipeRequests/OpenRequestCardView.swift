//
//  OpenRequestCardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import FirebaseFirestore
import SwiftUI

struct OpenRequestCardView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(SnackbarManager.self) private var snackbarManager
    let request: SwipeRequest
    var isExpanded: Bool = false

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
                expandedStateView
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var expandedStateView: some View {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Requester:")
                    .fontWeight(.semibold)
                UserInfoView(userId: request.requesterId)
            }
        }
        .font(.body)
        
        Button("Accept Request") {
            acceptRequest()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }

    private func acceptRequest() {
        guard let userId = authManager.user?.uid else {
            // Should never happen, but just in case
            print("User not logged in, cannot accept request.")
            return
        }

        var updatedRequest = request
        updatedRequest.swiperId = userId
        updatedRequest.status = .inProgress

        SwipeRequestManager.shared.addSwipeRequestToDatabase(swipeRequest: updatedRequest, isEdit: true)
        snackbarManager.show(title: "Request accepted", style: .success)
    }
}

#Preview {
    VStack(spacing: 20) {
        if let request = SwipeRequest.mockRequests.first {
            OpenRequestCardView(request: request, isExpanded: false)
            OpenRequestCardView(request: request, isExpanded: true)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .environment(SnackbarManager())
    .environment(AuthenticationManager())
} 
