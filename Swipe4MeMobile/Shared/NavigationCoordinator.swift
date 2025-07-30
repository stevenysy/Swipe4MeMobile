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
    
    // Private database instance for push notification handling
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
        
        // Listen for review sheet notification taps
        NotificationCenter.default.addObserver(
            forName: .openReviewSheetNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let requestId = notification.userInfo?["requestId"] as? String {
                Task { @MainActor in
                    await self?.handleReviewSheetNavigation(requestId: requestId)
                }
            }
        }
    }
    
    // MARK: - Chat Navigation
    
    private func handleChatNavigation(chatRoomId: String) {
        pendingChatRoomId = chatRoomId
        shouldOpenChat = true
    }
    
    // MARK: - Review Sheet Navigation
    
    private func handleReviewSheetNavigation(requestId: String) async {
        do {
            // Fetch the request from Firestore
            let requestDoc = try await db.collection("swipeRequests").document(requestId).getDocument()
            if let request = try? requestDoc.data(as: SwipeRequest.self) {
                showReviewSheet(request: request)
            } else {
                print("Failed to load request for review sheet: \(requestId)")
            }
        } catch {
            print("Error fetching request for review sheet: \(error.localizedDescription)")
        }
    }
    
    func clearPendingNavigation() {
        pendingChatRoomId = nil
        shouldOpenChat = false
    }
    
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
        await ReviewManager.shared.createReviewReminder(userId: currentUserId, requestId: requestId)
    }
    
    func checkForPendingReviewReminders(userId: String) async {
        if let request = await ReviewManager.shared.checkForPendingReviewReminders(userId: userId) {
            await MainActor.run {
                showReviewSheet(request: request)
            }
        }
    }
} 
