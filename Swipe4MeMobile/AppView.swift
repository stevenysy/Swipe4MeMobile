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
    @State private var selectedTab = 0
    @State private var userRole: UserRole = .requester

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                UserDashboardView(userRole: userRole)
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            // Dummy view for the role switch action.
            // This view is never shown. Tapping its tab item triggers the role switch.
            Text("")
                .tabItem {
                    Label("Switch Role", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(1)

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
                .tag(2)
            } else {
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
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 1 {
                // This is the switch tab. Toggle the role...
                userRole = (userRole == .requester) ? .swiper : .requester
                // ...and then immediately jump back to the previous tab.
                selectedTab = oldTab
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .sensoryFeedback(.selection, trigger: userRole)
    }
}

#Preview {
    AppView()
        .environment(AuthenticationManager())
}
