//
//  AppView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI

struct AppView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                HomeView()
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // Create Request Tab
            NavigationStack {
                CreateSwipeRequestView(request: SwipeRequest())
                    .environment(authManager)
            }
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Create Request")
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
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
    }
}

#Preview {
    AppView()
        .environment(AuthenticationManager())
}
