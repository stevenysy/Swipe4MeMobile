//
//  MyRequestsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/18/25.
//

import FirebaseFirestore
import SwiftUI

// A view that displays the current user's swipe requests.
// It uses the `AuthenticationManager` from the environment to identify the user
// and fetches the relevant requests from Firestore.
struct MyRequestsView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        // Since MasterView ensures this view is only shown for authenticated users,
        // we can safely access the user's ID.
        if let userId = authManager.user?.uid {
            MyRequestsListView(requesterId: userId)
                .navigationTitle("My Requests")
        } else {
            // A fallback for the unlikely case that the user ID is unavailable.
            // This state should not be reached in normal app flow.
            ContentUnavailableView(
                "Cannot Load Requests",
                systemImage: "exclamationmark.triangle",
                description: Text("Could not retrieve your user information.")
            )
            .navigationTitle("My Requests")
        }
    }
}

// A private view responsible for querying and displaying the list of requests
// for a specific user.
private struct MyRequestsListView: View {
    @FirestoreQuery var requests: [SwipeRequest]

    // Initializes the Firestore query to fetch requests for the given user ID.
    init(requesterId: String) {
        // We initialize the query here because it depends on a dynamic value (requesterId).
        // The _requests syntax gives us access to the underlying FirestoreQuery
        // property wrapper so we can configure it when the view is created.
        self._requests = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("requesterId", isEqualTo: requesterId),
                .order(by: "meetingTime", descending: false),
            ]
        )
    }

    var body: some View {
        MyRequestsContentView(requests: requests)
    }
}

private struct MyRequestsContentView: View {
    let requests: [SwipeRequest]

    var body: some View {
        Group {
            if requests.isEmpty {
                ContentUnavailableView(
                    "No Requests Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("You haven't made any swipe requests yet.")
                )
            } else {
                List(requests) { request in
                    requestRow(for: request)
                }
                .listStyle(.plain)
            }
        }
    }

    // Builds a single row for the request list.
    private func requestRow(for request: SwipeRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(request.location.rawValue)
                    .font(.headline)
                Text("Meeting at: \(request.meetingTime.dateValue(), style: .time)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            statusPill(for: request.status)
        }
        .padding(.vertical, 8)
    }

    // Creates a colored status indicator pill.
    private func statusPill(for status: RequestStatus) -> some View {
        Text(status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(for: status).opacity(0.15))
            .foregroundColor(statusColor(for: status))
            .cornerRadius(8)
    }

    // Determines the color for a given request status.
    private func statusColor(for status: RequestStatus) -> Color {
        switch status {
        case .open: .green
        case .inProgress: .blue
        case .awaitingReview: .orange
        case .complete: .purple
        case .canceled: .red
        }
    }
}

#Preview {
    NavigationView {
        MyRequestsContentView(requests: SwipeRequest.mockRequests)
            .navigationTitle("My Requests")
    }
}
