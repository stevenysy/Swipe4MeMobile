//
//  Swipe4MeMobileApp.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/5/25.
//

import FirebaseCore
import FirebaseMessaging
import SwiftUI
import UserNotifications

// MARK: - Notification Names
extension Notification.Name {
    static let openChatNotification = Notification.Name("openChatNotification")
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        
        // Set up delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // APNS token received - pass to FCM
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // APNS registration failed
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task {
            print("FCM token received")
            await NotificationManager.shared.handleTokenRefresh()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap
        if let notificationType = userInfo["type"] as? String,
           shouldOpenChat(for: notificationType),
           let chatRoomId = userInfo["chatRoomId"] as? String {
            
            // Post notification to SwiftUI views
            NotificationCenter.default.post(
                name: .openChatNotification,
                object: nil,
                userInfo: ["chatRoomId": chatRoomId]
            )
        }
        
        completionHandler()
    }

    private func shouldOpenChat(for notificationType: String) -> Bool {
        return notificationType == "chat_message" || notificationType == "change_proposal"
    }
}

@main
struct Swipe4MeMobileApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            MasterView()
        }
    }
}
