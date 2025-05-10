//
//  LoginView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/6/25.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) var authManager
    var body: some View {
        Text("Welcome to Swipe4Me!")

        GoogleSignInButton
    }

    var GoogleSignInButton: some View {
        Button {
            Task {
                _ = await authManager.signInWithGoogle()
            }
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Image("Google")
                Text("Sign in with Google")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 35)
        }
        .foregroundStyle(.primary)
        .buttonStyle(.bordered)
        .cornerRadius(10)
    }
}

#Preview {
    LoginView()
        .environment(AuthenticationManager())
}
