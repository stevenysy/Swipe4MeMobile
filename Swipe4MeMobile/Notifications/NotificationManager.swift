import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import Foundation

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func setupNotificationsForUser(_ userId: String) async {
        await requestNotificationPermissions()
        // Add a small delay to ensure APNS registration completes
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await updateFCMToken(for: userId)
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                // Wait a bit for APNS registration to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        } catch {
            print("Failed to request notification permissions: \(error)")
        }
    }
    
    func updateFCMToken(for userId: String) async {
        do {
            let token = try await Messaging.messaging().token()
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "lastTokenUpdate": Timestamp()
            ], merge: true)
print("FCM token updated successfully")
        } catch {
            print("Failed to update FCM token: \(error)")
        }
    }
}
