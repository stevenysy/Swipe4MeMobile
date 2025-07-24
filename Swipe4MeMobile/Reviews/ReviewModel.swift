//
//  ReviewModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import FirebaseFirestore
import Foundation

struct Review: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    var requestId: String
    var reviewerId: String  // The user who submitted the review (can be requester OR swiper)
    var revieweeId: String  // The user being reviewed (can be swiper OR requester)
    var rating: Int         // 1-5 stars
    var createdAt: Timestamp
    
    init(
        requestId: String,
        reviewerId: String,
        revieweeId: String,
        rating: Int
    ) {
        self.requestId = requestId
        self.reviewerId = reviewerId
        self.revieweeId = revieweeId
        self.rating = rating
        self.createdAt = Timestamp()
    }
}

// MARK: - User Review Reminders

struct PendingReviewReminder: Codable, Identifiable, Equatable, Hashable {
    var id: String { requestId } // Use requestId as identifier
    let requestId: String
    var reminderCount: Int = 0
    var needsReminder: Bool = false
    var reminderShown: Bool = false
    var createdAt: Timestamp = Timestamp()
    
    init(
        requestId: String,
        reminderCount: Int = 0,
        needsReminder: Bool = false,
        reminderShown: Bool = false
    ) {
        self.requestId = requestId
        self.reminderCount = reminderCount
        self.needsReminder = needsReminder
        self.reminderShown = reminderShown
        self.createdAt = Timestamp()
    }
}

struct UserReviewReminders: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String? // Will be the userId
    let userId: String
    var pendingReminders: [String: PendingReviewReminder] = [:] // requestId -> reminder
    var lastUpdated: Timestamp = Timestamp()
    
    init(userId: String) {
        self.userId = userId
        self.pendingReminders = [:]
        self.lastUpdated = Timestamp()
    }
    
    // MARK: - Helper Methods
    
    /// Gets a specific pending reminder by request ID
    func getPendingReminder(for requestId: String) -> PendingReviewReminder? {
        return pendingReminders[requestId]
    }
    
    /// Adds or updates a pending reminder
    mutating func setPendingReminder(_ reminder: PendingReviewReminder) {
        pendingReminders[reminder.requestId] = reminder
        lastUpdated = Timestamp()
    }
    
    /// Removes a pending reminder (when review is completed)
    mutating func removePendingReminder(for requestId: String) {
        pendingReminders.removeValue(forKey: requestId)
        lastUpdated = Timestamp()
    }
    
    /// Gets the next reminder that needs to be shown
    func getNextReminderToShow() -> PendingReviewReminder? {
        return pendingReminders.values.first { $0.needsReminder && !$0.reminderShown }
    }
    
    /// Gets count of all pending reminders
    var totalPendingCount: Int {
        return pendingReminders.values.filter { $0.needsReminder }.count
    }
} 