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
        
        MicrosoftSignInButton
    }
    
    var GoogleSignInButton: some View {
        Button {
            Task {
                guard let firebaseUser = await authManager.signInWithGoogle() else { return }
                
                if authManager.isFirstTimeSignIn {
                    let newUser = UserManager.shared.createSfmUserFromGoogleSignIn(firebaseUser: firebaseUser)
                    await UserManager.shared.createNewUser(newUser: newUser)
                } else {
                    let existingUser = await UserManager.shared.getUser(userId: firebaseUser.uid)
                    UserManager.shared.setCurrentUser(existingUser)
                }
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
                } else {
                    let existingUser = await UserManager.shared.getUser(userId: firebaseUser.uid)
                    UserManager.shared.setCurrentUser(existingUser)
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Image("Microsoft")
                Text("Sign in with Microsoft")
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
