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
}
