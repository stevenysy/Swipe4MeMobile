//
//  AppView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI

enum UserRole: String, CaseIterable {
    case requester = "Requester"
    case swiper = "Swiper"
}

struct AppView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var userRole: UserRole = .requester

    var body: some View {
        TabView {
            // Home Tab
            NavigationStack {
                UserDashboardView(userRole: $userRole)
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            // Conditional Requests Tab
            if userRole == .requester {
                NavigationStack {
                    MyRequestsView()
                        .environment(authManager)
                }
                .tabItem {
                    Image(systemName: "person.text.rectangle.fill")
                    Text("My Requests")
                }
                .tag(1)
            } else {
                NavigationStack {
                    OpenRequestsView()
                        .environment(authManager)
                }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Open Requests")
                }
                .tag(1)
            }
        }
        .sensoryFeedback(.selection, trigger: userRole)
    }
}

#Preview {
    AppView()
        .environment(AuthenticationManager())
}
