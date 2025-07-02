//
//  MyRequestsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/18/25.
//

import SwiftUI
import FirebaseFirestore

// Filter options for user requests
enum RequestFilter: String, CaseIterable {
    case requester = "Requester"
    case swiper = "Swiper"
}

// A view that displays the current user's upcoming sessions with filtering capabilities.
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
                UserRequestsListView(userId: userId)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink {
                                CreateSwipeRequestView(request: SwipeRequest())
                            } label: {
                                Image(systemName: "plus")
                            }
                        }

                        ToolbarItem(placement: .navigationBarLeading) {
                            Text("My Requests")
                                .font(.largeTitle)
                                .fontWeight(.bold)
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

// A private view that handles the Firestore queries for user requests
private struct UserRequestsListView: View {
    @State private var currentFilter: RequestFilter? = nil
    @Environment(SnackbarManager.self) private var snackbarManager
    
    let userId: String
    
    // We'll use multiple queries and switch between them based on filter
    @FirestoreQuery var requesterRequests: [SwipeRequest]
    @FirestoreQuery var swiperRequests: [SwipeRequest]
    
    // Combined requests based on current filter
    private var filteredRequests: [SwipeRequest] {
        switch currentFilter {
        case nil:
            // Show all requests when no filter is active
            let combined = requesterRequests + swiperRequests
            return combined.sorted { $0.meetingTime.dateValue() < $1.meetingTime.dateValue() }
        case .requester:
            return requesterRequests
        case .swiper:
            return swiperRequests
        }
    }
    
    init(userId: String) {
        self.userId = userId
        
        let now = Timestamp()
        
        // Query for requests where user is the requester (future only)
        self._requesterRequests = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("requesterId", isEqualTo: userId),
                .where("meetingTime", isGreaterThan: now),
                .order(by: "meetingTime", descending: false)
            ]
        )
        
        // Query for requests where user is the swiper (future only)
        self._swiperRequests = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("swiperId", isEqualTo: userId),
                .where("meetingTime", isGreaterThan: now),
                .order(by: "meetingTime", descending: false)
            ]
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Upcoming Sessions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                Spacer()
            }
            
            // Mutually exclusive filter buttons
            HStack(spacing: 8) {
                ForEach(RequestFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if currentFilter == filter {
                                // If this filter is already active, turn it off
                                currentFilter = nil
                            } else {
                                // Switch to this filter
                                currentFilter = filter
                            }
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(currentFilter == filter ? 
                                          Color.accentColor : Color.secondary.opacity(0.2))
                            }
                            .foregroundColor(currentFilter == filter ? 
                                           .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            SwipeRequestGroupedListView(
                requests: filteredRequests,
                userId: userId,
                emptyStateView: {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Upcoming Sessions")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("You don't have any scheduled swipe sessions yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 200)
                }
            )
        }
        .animation(.easeInOut, value: currentFilter)
        .padding(.top)
    }
}

#Preview {
    MyRequestsView()
        .environment(AuthenticationManager())
        .environment(SnackbarManager())
}
