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
}
