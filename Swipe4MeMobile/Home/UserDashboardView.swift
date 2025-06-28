//
//  UserDashboardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI

struct UserDashboardView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack {
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

                    // MARK: - Grouped Requests List
                    GroupedRequestsListView(
                        requests: [],
                        cardView: { _ in Text("Request Card") },
                        emptyStateView: { Text("No Requests") }
                    )
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
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

#Preview {
    UserDashboardView()
        .environment(AuthenticationManager())
}
