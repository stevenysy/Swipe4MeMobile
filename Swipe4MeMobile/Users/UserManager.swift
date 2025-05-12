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
}
