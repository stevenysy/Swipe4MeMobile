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
    case all = "All"
    case requester = "Requester"
    case swiper = "Swiper"
}

// Activity filter options
enum ActivityFilter: String, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    case all = "All"
}

// Date filter options
enum DateFilter: String, CaseIterable {
    case upcoming = "Future"
    case past = "Past"
    case all = "All"
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
    @State private var currentFilter: RequestFilter = .all
    @State private var currentActivityFilter: ActivityFilter = .active
    @State private var currentDateFilter: DateFilter = .upcoming
    @Environment(SnackbarManager.self) private var snackbarManager
    
    let userId: String
    
    // Original queries - fetch all user requests
    @FirestoreQuery var requesterRequests: [SwipeRequest]
    @FirestoreQuery var swiperRequests: [SwipeRequest]
    
    // Combined requests based on current filters
    private var filteredRequests: [SwipeRequest] {
        // First, get all requests based on role filter
        let roleFilteredRequests: [SwipeRequest]
        switch currentFilter {
        case .all:
            roleFilteredRequests = requesterRequests + swiperRequests
        case .requester:
            roleFilteredRequests = requesterRequests
        case .swiper:
            roleFilteredRequests = swiperRequests
        }
        
        // Then filter by activity status
        let activityFilteredRequests: [SwipeRequest]
        switch currentActivityFilter {
        case .active:
            // Active: open, scheduled, inProgress, awaitingReview
            activityFilteredRequests = roleFilteredRequests.filter { request in
                [.open, .scheduled, .inProgress, .awaitingReview].contains(request.status)
            }
        case .inactive:
            // Inactive: complete, canceled
            activityFilteredRequests = roleFilteredRequests.filter { request in
                [.complete, .canceled].contains(request.status)
            }
        case .all:
            activityFilteredRequests = roleFilteredRequests
        }
        
        // Finally, filter by date
        let now = Date()
        let dateFilteredRequests: [SwipeRequest]
        switch currentDateFilter {
        case .upcoming:
            dateFilteredRequests = activityFilteredRequests.filter { $0.meetingTime.dateValue() > now }
        case .past:
            dateFilteredRequests = activityFilteredRequests.filter { $0.meetingTime.dateValue() <= now }
        case .all:
            dateFilteredRequests = activityFilteredRequests
        }
        
        // Sort by meeting time - most relevant first for each category
        return dateFilteredRequests.sorted { 
            if currentDateFilter == .past || currentActivityFilter == .inactive {
                return $0.meetingTime.dateValue() > $1.meetingTime.dateValue() // Most recent first for past/inactive
            } else {
                return $0.meetingTime.dateValue() < $1.meetingTime.dateValue() // Soonest first for upcoming/active
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
            // All filters in one row with labels
            VStack(alignment: .leading, spacing: 8) {
                // Filter labels
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        // Activity filter dropdown
                        Menu {
                            ForEach(ActivityFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentActivityFilter = filter
                                    }
                                }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if currentActivityFilter == filter {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentActivityFilter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .imageScale(.small)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        // Date filter dropdown
                        Menu {
                            ForEach(DateFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentDateFilter = filter
                                    }
                                }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if currentDateFilter == filter {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentDateFilter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .imageScale(.small)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Role")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        // Role filter dropdown
                        Menu {
                            ForEach(RequestFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentFilter = filter
                                    }
                                }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if currentFilter == filter {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentFilter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .imageScale(.small)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            
            SwipeRequestGroupedListView(
                requests: filteredRequests,
                userId: userId,
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
        .animation(.easeInOut, value: currentFilter)
        .animation(.easeInOut, value: currentActivityFilter)
        .animation(.easeInOut, value: currentDateFilter)
        .padding(.top)
    }
    
    private var emptyStateIcon: String {
        // Prioritize activity status, then date for icon selection
        switch currentActivityFilter {
        case .active:
            return currentDateFilter == .past ? "clock.badge.exclamationmark" : "calendar.badge.exclamationmark"
        case .inactive:
            return "archivebox"
        case .all:
            return currentDateFilter == .past ? "clock.badge.exclamationmark" : "calendar.badge.exclamationmark"
        }
    }
    
    private var emptyStateTitle: String {
        // Combine activity and date context for title
        switch (currentActivityFilter, currentDateFilter) {
        case (.active, .upcoming):
            return "No Upcoming Active Requests"
        case (.active, .past):
            return "No Past Active Requests"
        case (.active, .all):
            return "No Active Requests"
        case (.inactive, .upcoming):
            return "No Upcoming Inactive Requests"
        case (.inactive, .past):
            return "No Past Inactive Requests"
        case (.inactive, .all):
            return "No Inactive Requests"
        case (.all, .upcoming):
            return "No Upcoming Requests"
        case (.all, .past):
            return "No Past Requests"
        case (.all, .all):
            return "No Requests"
        }
    }
    
    private var emptyStateMessage: String {
        // Context-aware messaging based on filter combination
        switch (currentActivityFilter, currentDateFilter) {
        case (.active, .upcoming):
            return "You don't have any upcoming active requests that need attention."
        case (.active, .past):
            return "You don't have any past active requests. This might include requests awaiting review from earlier meetings."
        case (.active, .all):
            return "You don't have any active requests that need attention."
        case (.inactive, .upcoming):
            return "You don't have any upcoming requests that are completed or canceled."
        case (.inactive, .past):
            return "You don't have any past requests that are completed or canceled."
        case (.inactive, .all):
            return "You don't have any completed or canceled requests yet."
        case (.all, .upcoming):
            return "You don't have any upcoming requests scheduled."
        case (.all, .past):
            return "You don't have any past requests in your history."
        case (.all, .all):
            return "You don't have any swipe requests yet."
        }
    }
}

#Preview {
    MyRequestsView()
        .environment(AuthenticationManager())
        .environment(SnackbarManager())
}
