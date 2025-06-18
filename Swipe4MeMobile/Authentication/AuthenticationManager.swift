//
//  AuthenticationManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/6/25.
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum AuthenticationState {
    case unauthenticated
    case authenticated
    case progress
}

@MainActor
@Observable class AuthenticationManager {
    
    var authState: AuthenticationState = .progress
    var isFirstTimeSignIn = false
    var user: User?
    var errorMessage = ""
    
    init() {
        registerAuthStateHandler()
    }
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    private func registerAuthStateHandler() {
        if authStateHandler == nil {
            authStateHandler = Auth.auth().addStateDidChangeListener { auth, user in
                self.user = user
                self.authState = user == nil ? .unauthenticated : .authenticated
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print(error)
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteAccount() async -> Bool {
        do {
            try await user?.delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            print(errorMessage)
            return false
        }
    }
    
}

enum AuthenticationError: LocalizedError {
    case tokenError(message: String)
    case nonVanderbiltEmailError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .tokenError(let message):
            return message
        case .nonVanderbiltEmailError(let message):
            return message
        }
    }
}

// Google sign in
extension AuthenticationManager {
    func signInWithGoogle() async -> SFMUser? {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fatalError("No client ID found in Firebase configuration")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController
        else {
            print("There is no root view controller!")
            return nil
        }
        
        do {
            let userAuthentication = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController)
            
            let user = userAuthentication.user
            guard let idToken = user.idToken else {
                throw AuthenticationError.tokenError(message: "ID token missing")
            }
            
            // Check for vanderbilt email domain
            guard let email = user.profile?.email,
                  email.hasSuffix("@vanderbilt.edu")
            else {
                throw AuthenticationError.nonVanderbiltEmailError(
                    message: "Please use your Vanderbilt email address")
            }
            
            let accessToken = user.accessToken
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken.tokenString,
                accessToken: accessToken.tokenString)
            
            let result = try await Auth.auth().signIn(with: credential)
            if let isNewUser = result.additionalUserInfo?.isNewUser, isNewUser {
                isFirstTimeSignIn = true
            }
            let firebaseUser = result.user
            print(
                "User \(firebaseUser.uid) signed in with email \(firebaseUser.email ?? "unknown")")
            return createSfmUserFromGoogleSignIn(firebaseUser: firebaseUser)
        } catch {
            print(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    private func createSfmUserFromGoogleSignIn(firebaseUser: FirebaseAuth.User) -> SFMUser {
        dump(firebaseUser)
        
        let fullName = firebaseUser.displayName ?? ""
        let splitFullName = fullName.split(separator: " ")
        let firstName = String(splitFullName.first ?? "")
        let lastName = splitFullName.count >= 2 ? String(splitFullName.last ?? "") : ""
        let email = firebaseUser.email ?? ""
        let profilePictureUrl = firebaseUser.photoURL?.absoluteString ?? ""
        
        return SFMUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            profilePictureUrl: profilePictureUrl
        )
    }
}

// Microsoft sign in
extension AuthenticationManager {
    func signInWithMicrosoft() async -> SFMUser? {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//              let window = windowScene.windows.first,
//              let rootViewController = window.rootViewController
//        else {
//            print("There is no root view controller!")
//            return nil
//        }
        
        do {
            // Create Microsoft provider
            let provider = OAuthProvider(providerID: "microsoft.com")
            
            // Configure the provider (optional)
            provider.customParameters = [
                "prompt": "select_account"
            ]
            
            // Step 1: Get the OAuth credential by presenting the Microsoft login.
            let credential = try await provider.credential(with: nil)
            
            // Step 2: Use credential to sign in to Firebase
            let result = try await Auth.auth().signIn(with: credential)
            
            // Check for Vanderbilt email domain
            guard let email = result.user.email,
                  email.hasSuffix("@vanderbilt.edu")
            else {
                throw AuthenticationError.nonVanderbiltEmailError(
                    message: "Please use your Vanderbilt email address")
            }
            
            // Check if this is a new user
            if let isNewUser = result.additionalUserInfo?.isNewUser, isNewUser {
                isFirstTimeSignIn = true
            }
            
            let firebaseUser = result.user
            print("User \(firebaseUser.uid) signed in with email \(firebaseUser.email ?? "unknown")")
            
            return createSfmUserFromMicrosoftSignIn(firebaseUser: firebaseUser)
            
        } catch {
            print(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    private func createSfmUserFromMicrosoftSignIn(firebaseUser: FirebaseAuth.User) -> SFMUser {
        // Name parsing needs to be different for MS because the display name is
        // in Last, First format
        let fullName = firebaseUser.displayName ?? ""
        let splitFullName = fullName.split(separator: ", ")
        let lastName = String(splitFullName.first ?? "")
        let firstName = splitFullName.count >= 2 ? String(splitFullName.last ?? "") : ""
        let email = firebaseUser.email ?? ""
        let profilePictureUrl = firebaseUser.photoURL?.absoluteString ?? ""
        
        return SFMUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            profilePictureUrl: profilePictureUrl
        )
    }
}
