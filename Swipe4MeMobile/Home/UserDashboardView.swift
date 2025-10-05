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

                    // MARK: - Today's Sessions Section
                    if let userId = authManager.user?.uid {
                        TodaysSessionsView(userId: userId)
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
                    Menu {
                        Button(role: .destructive, action: {
                            authManager.signOut()
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                    }
                    .tint(.primary)
                }
            }
        }
    }
}

// A private view that handles the Firestore queries for today's sessions
private struct TodaysSessionsView: View {
    let userId: String
    
    // Queries for today's sessions
    @FirestoreQuery var requesterTodaySessions: [SwipeRequest]
    @FirestoreQuery var swiperTodaySessions: [SwipeRequest]
    
    // Combined and sorted today's sessions
    private var todaysSessions: [SwipeRequest] {
        let combined = requesterTodaySessions + swiperTodaySessions
        return combined.sorted { $0.meetingTime.dateValue() < $1.meetingTime.dateValue() }
    }
    
    init(userId: String) {
        self.userId = userId
        
        // Get today's date range
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let startTimestamp = Timestamp(date: startOfDay)
        let endTimestamp = Timestamp(date: endOfDay)
        
        // Query for requests where user is the requester (today only)
        self._requesterTodaySessions = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("requesterId", isEqualTo: userId),
                .where("meetingTime", isGreaterThanOrEqualTo: startTimestamp),
                .where("meetingTime", isLessThan: endTimestamp),
                .order(by: "meetingTime", descending: false)
            ]
        )
        
        // Query for requests where user is the swiper (today only)
        self._swiperTodaySessions = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("swiperId", isEqualTo: userId),
                .where("meetingTime", isGreaterThanOrEqualTo: startTimestamp),
                .where("meetingTime", isLessThan: endTimestamp),
                .order(by: "meetingTime", descending: false)
            ]
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Sessions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                Spacer()
            }
            
            SwipeRequestListView(
                requests: todaysSessions,
                userId: userId,
                emptyStateView: {
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: "calendar.day.timeline.leading")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Sessions Today")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("You don't have any swipe sessions scheduled for today.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 200)
                }
            )
        }
    }
}

#Preview {
    UserDashboardView()
        .environment(AuthenticationManager())
}
