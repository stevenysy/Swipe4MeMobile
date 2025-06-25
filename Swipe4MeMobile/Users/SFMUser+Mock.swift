//
//  SFMUser+Mock.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import Foundation

extension SFMUser {
    static var mockUsers: [SFMUser] {
        return [
            SFMUser(
                id: "user_swiper_1",
                firstName: "John",
                lastName: "Appleseed",
                email: "john.appleseed@example.com",
                profilePictureUrl: "https://randomuser.me/api/portraits/men/1.jpg"
            ),
            SFMUser(
                id: "user_swiper_2",
                firstName: "Jane",
                lastName: "Doe",
                email: "jane.doe@example.com",
                profilePictureUrl: "https://randomuser.me/api/portraits/women/2.jpg"
            ),
            SFMUser(
                id: "user_swiper_3",
                firstName: "Peter",
                lastName: "Jones",
                email: "peter.jones@example.com",
                profilePictureUrl: "https://randomuser.me/api/portraits/men/3.jpg"
            )
        ]
    }
    
    static var mockUser: SFMUser {
        mockUsers[0]
    }
} 