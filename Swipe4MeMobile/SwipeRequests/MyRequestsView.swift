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

    @State private var selectedRequest: SwipeRequest?
    @State private var requestToDelete: SwipeRequest?

    var body: some View {
        NavigationStack {
            // Since MasterView ensures this view is only shown for authenticated users,
            // we can safely access the user's ID.
            if let userId = authManager.user?.uid {
                MyRequestsListView(
                    requesterId: userId, selectedRequest: $selectedRequest,
                    requestToDelete: $requestToDelete
                )
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
        .alert(
            "Delete Request", isPresented: .constant(requestToDelete != nil),
            presenting: requestToDelete
        ) { request in
            Button("Delete", role: .destructive) {
                if let requestToDelete = requestToDelete {
                    SwipeRequestManager.shared.deleteRequest(requestToDelete)
                    snackbarManager.show(title: "Request Deleted", style: .success)
                }
                self.requestToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                self.requestToDelete = nil
            }
        } message: { request in
            Text(
                "Are you sure you want to delete this swipe request for \(request.location.rawValue) at \(request.meetingTime.dateValue(), style: .time)? This action cannot be undone."
            )
        }
    }
}

// A private view responsible for querying and displaying the list of requests
// for a specific user.
private struct MyRequestsListView: View {
    @FirestoreQuery var requests: [SwipeRequest]

    @Binding var selectedRequest: SwipeRequest?
    @Binding var requestToDelete: SwipeRequest?

    // Initializes the Firestore query to fetch requests for the given user ID.
    init(
        requesterId: String, selectedRequest: Binding<SwipeRequest?>,
        requestToDelete: Binding<SwipeRequest?>
    ) {
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
        self._selectedRequest = selectedRequest
        self._requestToDelete = requestToDelete
    }

    var body: some View {
        GroupedRequestsListView(
            requests: requests,
            cardView: { request in
                SwipeRequestCardView(
                    request: request,
                    isExpanded: selectedRequest?.id == request.id,
                    onDelete: {
                        self.requestToDelete = request
                    },
                    onEdit: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            self.selectedRequest = nil
                        }
                    }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        if self.selectedRequest?.id == request.id {
                            self.selectedRequest = nil
                        } else {
                            self.selectedRequest = request
                        }
                    }
                }
            },
            emptyStateView: {
                ContentUnavailableView(
                    "No Requests Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("You haven't made any swipe requests yet.")
                )
            }
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: selectedRequest)
    }
}

#Preview {
    // We create a wrapper to provide the necessary state for the preview.
    struct PreviewWrapper: View {
        @State private var selectedRequest: SwipeRequest?
        @State private var requestToDelete: SwipeRequest?

        var body: some View {
            GroupedRequestsListView(
                requests: SwipeRequest.mockRequests,
                cardView: { request in
                    SwipeRequestCardView(
                        request: request,
                        isExpanded: selectedRequest?.id == request.id,
                        onDelete: {
                            self.requestToDelete = request
                        },
                        onEdit: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                self.selectedRequest = nil
                            }
                        }
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            if self.selectedRequest?.id == request.id {
                                self.selectedRequest = nil
                            } else {
                                self.selectedRequest = request
                            }
                        }
                    }
                },
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

    return NavigationStack {
        PreviewWrapper()
    }
    .environment(AuthenticationManager())
}
