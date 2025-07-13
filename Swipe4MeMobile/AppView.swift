//
//  AppView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI
import FirebaseAuth

// TODO: Get rid of the role selection!!!
// Users should be able to request swipes and register to swipe for others
// without having to switch roles.
// In the dashboard, we can just show the user's all future sessions and use
// different colors to indicate the role of the user.

struct AppView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var navigationCoordinator = NavigationCoordinator.shared

    var body: some View {
        TabView {
            // Home Tab
            NavigationStack {
                UserDashboardView()
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "square.grid.2x2.fill")
                Text("Dashboard")
            }
            .tag(0)

            // My Requests Tab
            NavigationStack {
                MyRequestsView()
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "person.text.rectangle.fill")
                Text("My Requests")
            }
            .tag(1)

            // Open Requests Tab
            NavigationStack {
                OpenRequestsView()
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Open Requests")
            }
            .tag(2)
        }
        .task {
            // Setup notifications for authenticated users when app launches
            if let currentUser = Auth.auth().currentUser {
                await NotificationManager.shared.setupNotificationsForUser(currentUser.uid)
                
                // Start listening to unread message counts
                ChatManager.shared.startListeningToUnreadCounts()
            }
        }
        .sheet(isPresented: $navigationCoordinator.shouldOpenChat) {
            if let chatRoomId = navigationCoordinator.pendingChatRoomId {
                ChatLoaderView(chatRoomId: chatRoomId)
                    .onDisappear {
                        navigationCoordinator.clearPendingNavigation()
                    }
            }
        }
    }
}

#Preview {
    AppView()
        .environment(AuthenticationManager())
}
