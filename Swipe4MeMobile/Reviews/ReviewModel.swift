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
    var isShown: Bool = false // Track if reminder has been shown (one-time only)
    var createdAt: Timestamp = Timestamp()
    
    // MARK: - Constants
    private static let reminderCooldownInterval: TimeInterval = 8 * 60 * 60 // 8 hours
    
    init(
        requestId: String,
        isShown: Bool = false
    ) {
        self.requestId = requestId
        self.isShown = isShown
        self.createdAt = Timestamp()
    }
    
    /// Check if the reminder should be shown based on creation time and shown status
    /// - Returns: True if the reminder should be shown, false otherwise
    func shouldShowAgain() -> Bool {
        // If already shown once, don't show again (one-time reminder policy)
        if isShown {
            return false
        }
        
        // Check if enough time has passed since reminder was created (8-hour cooldown)
        let timeSinceCreated = Date().timeIntervalSince(createdAt.dateValue())
        return timeSinceCreated >= Self.reminderCooldownInterval
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