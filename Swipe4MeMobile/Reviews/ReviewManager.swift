//
//  ReviewManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import FirebaseFirestore
import FirebaseAuth
import Foundation

@Observable
@MainActor
final class ReviewManager {
    static let shared = ReviewManager()
    let db = Firestore.firestore()
    var errorMessage = ""
    
    private init() {}
    
    /// Submits a review and updates the reviewee's rating statistics
    /// - Parameters:
    ///   - requestId: The ID of the swipe request being reviewed
    ///   - revieweeId: The ID of the user being reviewed (swiper)
    ///   - rating: The star rating (1-5)
    /// - Returns: True if successful, false otherwise
    func submitReview(requestId: String, revieweeId: String, rating: Int) async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return false
        }
        
        guard rating >= 1 && rating <= 5 else {
            errorMessage = "Rating must be between 1 and 5"
            return false
        }
        
        do {
            let batch = db.batch()
            
            // 1. Add the review
            let reviewRef = db.collection("reviews").document()
            let review = Review(
                requestId: requestId,
                reviewerId: currentUserId,
                revieweeId: revieweeId,
                rating: rating
            )
            try batch.setData(from: review, forDocument: reviewRef)
            
            // 2. Update reviewee's rating stats atomically
            let userRef = db.collection("users").document(revieweeId)
            batch.updateData([
                "ratingSum": FieldValue.increment(Int64(rating)),
                "totalReviews": FieldValue.increment(Int64(1))
            ], forDocument: userRef)
            
            // 3. Update request status to complete
            let requestRef = db.collection("swipeRequests").document(requestId)
            batch.updateData(["status": RequestStatus.complete.rawValue], forDocument: requestRef)
            
            // Commit the batch
            try await batch.commit()
            
            // 4. Calculate and update average rating (separate transaction)
            await updateUserAverage(userId: revieweeId)
            
            // 5. Clean up pending reminder for this request
            await removePendingReminder(userId: currentUserId, requestId: requestId)
            
            errorMessage = ""
            return true
            
        } catch {
            print("Error submitting review: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Updates the user's average rating based on their current rating stats
    /// - Parameter userId: The ID of the user to update
    private func updateUserAverage(userId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            let document = try await userRef.getDocument()
            
            guard let data = document.data(),
                  let totalReviews = data["totalReviews"] as? Int,
                  let ratingSum = data["ratingSum"] as? Int,
                  totalReviews > 0 else {
                print("Unable to calculate average rating for user: \(userId)")
                return
            }
            
            let newAverage = Double(ratingSum) / Double(totalReviews)
            let updateData: [String: Any] = ["averageRating": newAverage]
            try await userRef.updateData(updateData)
            
            print("Updated average rating for user \(userId): \(newAverage)")
            
        } catch {
            print("Error updating user average rating: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Removes a pending reminder from the user's reminders collection when review is completed
    /// - Parameters:
    ///   - userId: The user ID who completed the review
    ///   - requestId: The request ID that was reviewed
    private func removePendingReminder(userId: String, requestId: String) async {
        do {
            let userRemindersRef = db.collection("userReviewReminders").document(userId)
            let userRemindersDoc = try await userRemindersRef.getDocument()
            
            if userRemindersDoc.exists,
               var userReminders = try? userRemindersDoc.data(as: UserReviewReminders.self) {
                
                // Remove the pending reminder for this request
                userReminders.removePendingReminder(for: requestId)
                
                // Update the document
                try userRemindersRef.setData(from: userReminders)
                
                print("Removed pending reminder for user \(userId), request \(requestId)")
            }
        } catch {
            print("Error removing pending reminder: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
} 
