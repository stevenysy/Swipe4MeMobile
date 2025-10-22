//
//  LoginView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/6/25.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) var authManager
    @State private var tapCount = 0
    @State private var showGoogleSignIn = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height / 4)
                
                Text("Swipe4Me!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .onTapGesture {
                        tapCount += 1
                        if tapCount >= 5 {
                            showGoogleSignIn = true
                        }
                    }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if showGoogleSignIn {
                        GoogleSignInButton
                    }
                    
                    MicrosoftSignInButton
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: geometry.size.height / 3)
            }
        }
    }
    
    var GoogleSignInButton: some View {
        Button {
            Task {
                guard let firebaseUser = await authManager.signInWithGoogle() else { return }
                
                if authManager.isFirstTimeSignIn {
                    let newUser = UserManager.shared.createSfmUserFromGoogleSignIn(firebaseUser: firebaseUser)
                    await UserManager.shared.createNewUser(newUser: newUser)
                }
                
                // Setup notifications after successful sign-in
                await NotificationManager.shared.setupNotificationsForUser(firebaseUser.uid)
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
    
    var MicrosoftSignInButton: some View {
        Button {
            Task {
                guard let firebaseUser = await authManager.signInWithMicrosoft() else { return }
                
                if authManager.isFirstTimeSignIn {
                    let newUser = UserManager.shared.createSfmUserFromMicrosoftSignIn(firebaseUser: firebaseUser)
                    await UserManager.shared.createNewUser(newUser: newUser)
                }
                
                // Setup notifications after successful sign-in
                await NotificationManager.shared.setupNotificationsForUser(firebaseUser.uid)
            }
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text("Sign in with Vanderbilt Email")
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
