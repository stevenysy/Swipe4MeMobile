//
//  AppView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI
import FirebaseAuth

struct AppView: View {
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // App went to background - clear active chat
                Task {
                    await ChatManager.shared.clearActiveChat()
                    print("App backgrounded - cleared active chat")
                }
            case .active:
                print("App became active")
                // Check for pending review reminders
                Task {
                    if let currentUserId = authManager.user?.uid {
                        await navigationCoordinator.checkForPendingReviewReminders(userId: currentUserId)
                    }
                }
            case .inactive:
                print("App became inactive")
            @unknown default:
                break
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
        .sheet(isPresented: $navigationCoordinator.shouldShowReviewReminder) {
            if let reviewRequest = navigationCoordinator.pendingReviewRequest {
                ReviewSheetView(request: reviewRequest)
                    .onDisappear {
                        navigationCoordinator.clearReviewSheet(reviewSubmitted: false)
                    }
            }
        }
    }
}

#Preview {
    AppView()
        .environment(AuthenticationManager())
}
