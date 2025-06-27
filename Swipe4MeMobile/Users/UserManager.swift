//
//  UserManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/11/25.
//

import FirebaseFirestore
import FirebaseAuth

@Observable
@MainActor
final class UserManager {
    static let shared = UserManager()
    var errorMessage = ""
    let db = Firestore.firestore()
    
    private var userCache: [String: SFMUser] = [:]
    
    var userID: String { Auth.auth().currentUser?.uid ?? "" }
    var currentUser: SFMUser?
    
    private init() {}
    
    func createNewUser(newUser: SFMUser) async {
        do {
            try db.collection("users").document(userID).setData(from: newUser)
            currentUser = newUser
            print("User information is created \(String(describing: currentUser))")
        } catch {
            errorMessage = error.localizedDescription
            print(errorMessage)
        }
    }
    
    func setCurrentUser(_ user: SFMUser?) {
        currentUser = user
    }
    
    func getUser(userId: String) async -> SFMUser? {
        if let cachedUser = userCache[userId] {
            print("User \(userId) found in cache.")
            return cachedUser
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            let user = try document.data(as: SFMUser.self)
            userCache[userId] = user
            print("User \(userId) fetched from Firestore and cached.")
            return user
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - User Creation from Authentication Providers
    
    func createSfmUserFromGoogleSignIn(firebaseUser: FirebaseAuth.User) -> SFMUser {
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
    
    func createSfmUserFromMicrosoftSignIn(firebaseUser: FirebaseAuth.User) -> SFMUser {
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
