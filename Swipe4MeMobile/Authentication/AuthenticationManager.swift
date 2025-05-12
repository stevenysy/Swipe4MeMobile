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
            return createSfmUser(firebaseUser: firebaseUser)
        } catch {
            print(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    private func createSfmUser(firebaseUser: FirebaseAuth.User) -> SFMUser {
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
