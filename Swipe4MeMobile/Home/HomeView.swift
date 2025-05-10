//
//  HomeView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/9/25.
//

import SwiftUI

struct HomeView: View {
    @Environment(AuthenticationManager.self) var authManager
    
    var body: some View {
        Text("Home")
        
        Button {
            Task {
                authManager.signOut()
            }
        } label: {
            Text("Sign Out")
        }
    }
}

#Preview {
    HomeView()
}
