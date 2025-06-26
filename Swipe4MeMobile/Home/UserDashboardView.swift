//
//  UserDashboardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI

struct UserDashboardView: View {
    let userRole: UserRole

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
                        Text("User Info Section")
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
                        // TODO: Implement role switching
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
            }
        }
    }
}

#Preview {
    UserDashboardView(userRole: .requester)
}
