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
        if !reviewSubmitted {
            // Create reminder when user dismisses without submitting
            Task {
                await createReminder()
                // Clear state after reminder creation completes
                pendingReviewRequest = nil
                shouldShowReviewReminder = false
            }
        } else {
            // Clear state immediately if review was submitted
            pendingReviewRequest = nil
            shouldShowReviewReminder = false
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func createReminder() async {
        guard let request = pendingReviewRequest,
              let requestId = request.id else {
            print("Error: Missing request or user information for reminder creation")
            return
        }
        
        let currentUserId = UserManager.shared.userID
        
        do {
            // Get or create user reminders document
            let userRemindersRef = db.collection("userReviewReminders").document(currentUserId)
            let userRemindersDoc = try await userRemindersRef.getDocument()
            
            var userReminders: UserReviewReminders
            if userRemindersDoc.exists {
                userReminders = try userRemindersDoc.data(as: UserReviewReminders.self)
            } else {
                userReminders = UserReviewReminders(userId: currentUserId)
            }
            
            // Create new reminder with current timestamp (dismissal time)
            let reminder = PendingReviewReminder(requestId: requestId, isShown: false)
            
            // Update user reminders and save
            userReminders.setPendingReminder(reminder)
            try userRemindersRef.setData(from: userReminders)
            
            print("Created reminder for dismissed review sheet: \(requestId)")
        } catch {
            print("Error creating reminder on dismissal: \(error.localizedDescription)")
        }
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
                
                // Check if enough time has passed since reminder was created (8-hour cooldown)
                guard nextReminder.shouldShowAgain() else {
                    print("Skipping review reminder for request \(nextReminder.requestId) - still in cooldown or already shown")
                    return
                }
                
                // Fetch the actual SwipeRequest for the reminder
                let requestDoc = try await db
                    .collection("swipeRequests")
                    .document(nextReminder.requestId)
                    .getDocument()
                
                if let request = try? requestDoc.data(as: SwipeRequest.self) {
                    // Show the review sheet
                    showReviewSheet(request: request)
                    
                    // Mark reminder as shown in user reminders collection (one-time only)
                    var updatedUserReminders = userReminders
                    var updatedReminder = nextReminder
                    updatedReminder.isShown = true
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
