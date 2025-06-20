//
//  SwipeRequest+Mock.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/18/25.
//

import Foundation
import FirebaseFirestore

extension SwipeRequest {

    /// Convenience initializer for creating mock `SwipeRequest` instances with an `id`.
    /// This is useful for generating data for previews and tests.
    /// - Note: `createdAt` is handled by the model's default initializer.
    init(
        id: String,
        requesterId: String,
        swiperId: String,
        location: DiningLocation,
        meetingTime: Date,
        status: RequestStatus
    ) {
        self.init(
            requesterId: requesterId,
            swiperId: swiperId,
            location: location,
            meetingTime: Timestamp(date: meetingTime),
            status: status
        )
        self.id = id
    }

    static var mockRequests: [SwipeRequest] {
        return [
            SwipeRequest(
                id: "mock4",
                requesterId: "user_requester_4",
                swiperId: "user_swiper_4",
                location: .kissam,
                meetingTime: Date().addingTimeInterval(-86400), // Yesterday
                status: .complete
            ),
            SwipeRequest(
                id: "mock3",
                requesterId: "user_requester_3",
                swiperId: "user_swiper_3",
                location: .rand,
                meetingTime: Date().addingTimeInterval(-1800), // 30 minutes ago
                status: .awaitingReview
            ),
            SwipeRequest(
                id: "mock1",
                requesterId: "user_requester_1",
                swiperId: "user_swiper_1",
                location: .commons,
                meetingTime: Date().addingTimeInterval(3600), // In 1 hour
                status: .inProgress
            ),
            SwipeRequest(
                id: "mock2",
                requesterId: "user_requester_2",
                swiperId: "",
                location: .zeppos,
                meetingTime: Date().addingTimeInterval(7200), // In 2 hours
                status: .open
            ),
            SwipeRequest(
                id: "mock5",
                requesterId: "user_requester_5",
                swiperId: "",
                location: .ebi,
                meetingTime: Date().addingTimeInterval(172800), // In 2 days
                status: .canceled
            ),
        ]
    }

    static var emptyMockRequest = SwipeRequest()
} 
