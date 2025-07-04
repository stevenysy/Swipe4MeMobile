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
    @Environment(SnackbarManager.self) private var snackbarManager

    var body: some View {
        NavigationStack {
            // Since MasterView ensures this view is only shown for authenticated users,
            // we can safely access the user's ID.
            if let userId = authManager.user?.uid {
                MyRequestsListView(requesterId: userId)
                    .padding(.top)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            CreateSwipeRequestView(request: SwipeRequest())
                        } label: {
                            Image(systemName: "plus")
                        }
                        .padding(.top)
                    }

                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("My Requests")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                            .padding(.top)
                    }
                }
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
}

// A private view responsible for querying and displaying the list of requests
// for a specific user.
private struct MyRequestsListView: View {
    @FirestoreQuery var requests: [SwipeRequest]
    let requesterId: String

    // Initializes the Firestore query to fetch requests for the given user ID.
    init(requesterId: String) {
        self.requesterId = requesterId
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
        SwipeRequestGroupedListView(
            requests: requests,
            userId: requesterId,
            emptyStateView: {
                ContentUnavailableView(
                    "No Requests Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("You haven't made any swipe requests yet.")
                )
            }
        )
    }
}

#Preview {
    NavigationStack {
        SwipeRequestGroupedListView(
            requests: SwipeRequest.mockRequests,
            userId: "preview-user-id",
            emptyStateView: {
                ContentUnavailableView(
                    "No Requests Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("You haven't made any swipe requests yet.")
                )
            }
        )
    }
    .environment(AuthenticationManager())
    .environment(SnackbarManager())
}
