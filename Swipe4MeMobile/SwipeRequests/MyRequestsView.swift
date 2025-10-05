//
//  MyRequestsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/18/25.
//

import SwiftUI
import FirebaseFirestore

// Activity filter options
enum ActivityFilter: String, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
}

// A view that displays the current user's upcoming sessions with filtering capabilities.
// It uses the `AuthenticationManager` from the environment to identify the user
// and fetches the relevant requests from Firestore.
struct MyRequestsView: View {
    @Environment(AuthenticationManager.self) private var authManager

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
    @State private var currentActivityFilter: ActivityFilter = .active
    
    let userId: String
    
    // Original queries - fetch all user requests
    @FirestoreQuery var requesterRequests: [SwipeRequest]
    @FirestoreQuery var swiperRequests: [SwipeRequest]
    
    // Combined requests based on current filters
    private var filteredRequests: [SwipeRequest] {
        // Combine all user requests (both as requester and swiper)
        let allRequests = requesterRequests + swiperRequests
        
        // Filter by activity status using the isActive computed property
        let activityFilteredRequests: [SwipeRequest]
        switch currentActivityFilter {
        case .active:
            // Active: open (future), scheduled, inProgress, awaitingReview
            activityFilteredRequests = allRequests.filter { $0.isActive }
        case .inactive:
            // Inactive: complete, canceled, open (past)
            activityFilteredRequests = allRequests.filter { !$0.isActive }
        }
        
        // Sort by meeting time - most relevant first for each category
        return activityFilteredRequests.sorted { 
            if currentActivityFilter == .inactive {
                return $0.meetingTime.dateValue() > $1.meetingTime.dateValue() // Most recent first for inactive
            } else {
                return $0.meetingTime.dateValue() < $1.meetingTime.dateValue() // Soonest first for active
            }
        }
    }
    
    init(userId: String) {
        self.userId = userId
        
        // Query for requests where user is the requester (all time)
        self._requesterRequests = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("requesterId", isEqualTo: userId),
                .order(by: "meetingTime", descending: false)
            ]
        )
        
        // Query for requests where user is the swiper (all time)
        self._swiperRequests = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("swiperId", isEqualTo: userId),
                .order(by: "meetingTime", descending: false)
            ]
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Two-pill filter for Active/Inactive
            HStack(spacing: 0) {
                ForEach(ActivityFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentActivityFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background {
                                if currentActivityFilter == filter {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.accentColor)
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.clear)
                                }
                            }
                            .foregroundColor(currentActivityFilter == filter ? .white : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
            .padding(.horizontal)
            
            SwipeRequestGroupedListView(
                requests: filteredRequests,
                userId: userId,
                sortDaysDescending: currentActivityFilter == .inactive,
                emptyStateView: {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: emptyStateIcon)
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text(emptyStateTitle)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(emptyStateMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
        }
        .animation(.easeInOut, value: currentActivityFilter)
        .padding(.top)
    }
    
    private var emptyStateIcon: String {
        switch currentActivityFilter {
        case .active:
            return "calendar.badge.exclamationmark"
        case .inactive:
            return "archivebox"
        }
    }
    
    private var emptyStateTitle: String {
        switch currentActivityFilter {
        case .active:
            return "No Active Requests"
        case .inactive:
            return "No Inactive Requests"
        }
    }
    
    private var emptyStateMessage: String {
        switch currentActivityFilter {
        case .active:
            return "You don't have any active requests that need attention."
        case .inactive:
            return "You don't have any completed or canceled requests yet."
        }
    }
}

#Preview {
    MyRequestsView()
        .environment(AuthenticationManager())
}
