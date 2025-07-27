import SwiftUI
import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class NavigationCoordinator {
    static let shared = NavigationCoordinator()
    
    // Chat navigation state
    var pendingChatRoomId: String?
    var shouldOpenChat = false
    
    // Review reminder navigation state
    var pendingReviewRequest: SwipeRequest?
    var shouldShowReviewReminder = false
    
    // Private database instance
    private let db = Firestore.firestore()
    
    private init() {
        // Listen for notification taps
        NotificationCenter.default.addObserver(
            forName: .openChatNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let chatRoomId = notification.userInfo?["chatRoomId"] as? String {
                Task { @MainActor in
                    self?.handleChatNavigation(chatRoomId: chatRoomId)
                }
            }
        }
    }
    
    // MARK: - Chat Navigation
    
    private func handleChatNavigation(chatRoomId: String) {
        pendingChatRoomId = chatRoomId
        shouldOpenChat = true
    }
    
    func clearPendingNavigation() {
        pendingChatRoomId = nil
        shouldOpenChat = false
    }
    
    // MARK: - Review Sheet Navigation
    
    func showReviewSheet(request: SwipeRequest) {
        pendingReviewRequest = request
        shouldShowReviewReminder = true
    }
    
    func clearReviewSheet(reviewSubmitted: Bool) {
        pendingReviewRequest = nil
        shouldShowReviewReminder = false
    }
    
    func checkForPendingReviewReminders(userId: String) async {
        do {
            // Query single user document for pending reminders (O(1) instead of O(n))
            let userRemindersDoc = try await db
                .collection("userReviewReminders")
                .document(userId)
                .getDocument()
            
            // Check if user has any pending reminders
            if userRemindersDoc.exists,
               let userReminders = try? userRemindersDoc.data(as: UserReviewReminders.self),
               let nextReminder = userReminders.getNextReminderToShow() {
                
                // Fetch the actual SwipeRequest for the reminder
                let requestDoc = try await db
                    .collection("swipeRequests")
                    .document(nextReminder.requestId)
                    .getDocument()
                
                if let request = try? requestDoc.data(as: SwipeRequest.self) {
                    // Show the review sheet
                    showReviewSheet(request: request)
                    
                    // Mark reminder as shown in user reminders collection
                    var updatedUserReminders = userReminders
                    var updatedReminder = nextReminder
                    updatedReminder.reminderShown = true
                    updatedUserReminders.setPendingReminder(updatedReminder)
                    
                    try db.collection("userReviewReminders")
                        .document(userId)
                        .setData(from: updatedUserReminders)
                    
                    print("Showing review reminder for request: \(nextReminder.requestId)")
                }
                
                // TODO: Future Enhancement - Implement Queue System for Multiple Pending Reviews
                // - Track which reminders have been shown to rotate through all pending reviews
                // - Add a subtle indicator (badge/count) in the app showing total pending reviews
                // - Queue remaining reminders for future app opens so all reviews eventually get attention
                // - Consider priority-based ordering (most recent meetings first)
                // Note: userReminders.totalPendingCount can be used for the indicator badge
            }
        } catch {
            print("Error checking for pending review reminders: \(error.localizedDescription)")
        }
    }
} 