//
//  UserDashboardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI

struct UserDashboardView: View {
    @Binding var userRole: UserRole
    @State private var isShowingRoleSelection = false
    @Environment(AuthenticationManager.self) private var authManager

    private var navigationTitle: String {
        switch userRole {
        case .requester:
            "Requester Dashboard"
        case .swiper:
            "Swiper Dashboard"
        }
    }

    private var roleViewText: String {
        switch userRole {
        case .requester:
            "Requester View"
        case .swiper:
            "Swiper View"
        }
    }

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isShowingRoleSelection = true
                    }) {
                        HStack(alignment: .center) {
                            Text(roleViewText)
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                        }
                        .font(.title3.bold())
                    }
                    .tint(.primary)
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
            .sheet(isPresented: $isShowingRoleSelection) {
                RoleSelectionView(selectedRole: $userRole)
                    .presentationDetents([.fraction(0.25)])
            }
        }
    }
}

#Preview {
    UserDashboardView(userRole: .constant(.requester))
        .environment(AuthenticationManager())
}
