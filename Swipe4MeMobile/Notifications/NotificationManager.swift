import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import Foundation
import FirebaseAuth

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func setupNotificationsForUser(_ userId: String) async {
        await requestNotificationPermissions()
        // Update FCM token in case delegate fired before user was logged in
        await updateFCMToken(for: userId)
    }
    
    func handleTokenRefresh() async {
        guard let userId = Auth.auth().currentUser?.uid else { 
            return 
        }
        await updateFCMToken(for: userId)
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("Notification permissions granted")
            }
        } catch {
            print("Failed to request notification permissions: \(error)")
        }
    }
    
    private func updateFCMToken(for userId: String, retryCount: Int = 0) async {
        let maxRetries = 3
        let baseDelay: UInt64 = 500_000_000 // 0.5 seconds
        
        do {
            // Check if APNS token is available
            let apnsToken = Messaging.messaging().apnsToken
            if apnsToken == nil {
                if retryCount < maxRetries {
                    let delay = baseDelay * UInt64(pow(2.0, Double(retryCount))) // Exponential backoff
                    print("APNS token not ready, retrying in \(Double(delay) / 1_000_000_000)s...")
                    
                    try? await Task.sleep(nanoseconds: delay)
                    await updateFCMToken(for: userId, retryCount: retryCount + 1)
                    return
                } else {
                    print("APNS token not available after \(maxRetries) retries")
                    return
                }
            }
            
            let token = try await Messaging.messaging().token()
            
            guard !token.isEmpty else {
                print("Received empty FCM token")
                return
            }
            
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
