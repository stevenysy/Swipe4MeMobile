//
//  SwipeRequestManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/12/25.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class SwipeRequestManager {
    static let shared = SwipeRequestManager()
    let db = Firestore.firestore()
    var errorMessage = ""

    func addSwipeRequestToDatabase(swipeRequest: SwipeRequest, isEdit: Bool) {
        do {
            if isEdit, let requestId = swipeRequest.id {
                try db.collection("swipeRequests").document(requestId).setData(from: swipeRequest)
            } else {
                try db.collection("swipeRequests").addDocument(from: swipeRequest)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Deletes a request from Firestore and updates `errorMessage` on failure.
    ///
    /// - Parameter request: The `SwipeRequest` to remove.
    func deleteRequest(_ request: SwipeRequest) {
        guard let id = request.id else {
            self.errorMessage = "Request has no valid document ID."
            return
        }

        db.collection("swipeRequests").document(id).delete { error in
            if let error = error {
                self.errorMessage = error.localizedDescription   // <- Triggers alert
            } else {
                self.errorMessage = ""   // Clear any previous error
            }
        }
    }
}
