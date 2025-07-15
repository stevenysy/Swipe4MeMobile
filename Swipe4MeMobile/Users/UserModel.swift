//
//  UserModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/11/25.
//

import FirebaseFirestore

struct SFMUser: Codable, Identifiable {
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var email: String
    var profilePictureUrl: String
    var fcmToken: String?
    var lastTokenUpdate: Timestamp?
    var activeChat: String?  // ID of chat room user is currently viewing
}
