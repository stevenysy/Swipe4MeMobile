//
//  UserDashboardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI
import FirebaseFirestore

struct UserDashboardView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // MARK: - User Info Section
                    VStack {
                        if let currentUser = UserManager.shared.currentUser {
                            DashboardUserInfoView(user: currentUser)
                        } else {
                            Text("Loading user info...")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height / 4)

                    // MARK: - My Upcoming Sessions Section
                    if let userId = authManager.user?.uid {
                        UserRequestsListView(userId: userId)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        Text("Loading...")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Swipe4Me")
                    .font(.title2)
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        authManager.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                    }
                    .tint(.primary)
                }
            }
        }
    }
}

// Filter options for user requests
enum RequestFilter: String, CaseIterable {
    case requester = "Requester"
    case swiper = "Swiper"
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
                
                // TODO: Add button to create a new request
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
    }
}

#Preview {
    UserDashboardView()
        .environment(AuthenticationManager())
        .environment(SnackbarManager())
}
