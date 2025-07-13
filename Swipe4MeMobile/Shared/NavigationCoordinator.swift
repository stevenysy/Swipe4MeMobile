import SwiftUI
import Foundation

@Observable
@MainActor
final class NavigationCoordinator {
    static let shared = NavigationCoordinator()
    
    // Chat navigation state
    var pendingChatRoomId: String?
    var shouldOpenChat = false
    
    private init() {
        // Listen for notification taps
        NotificationCenter.default.addObserver(
            forName: .openChatNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let chatRoomId = notification.userInfo?["chatRoomId"] as? String {
                self?.handleChatNavigation(chatRoomId: chatRoomId)
            }
        }
    }
    
    private func handleChatNavigation(chatRoomId: String) {
        pendingChatRoomId = chatRoomId
        shouldOpenChat = true
    }
    
    func clearPendingNavigation() {
        pendingChatRoomId = nil
        shouldOpenChat = false
    }
} 