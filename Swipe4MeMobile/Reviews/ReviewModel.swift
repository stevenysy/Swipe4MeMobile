//
//  ReviewModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import FirebaseFirestore
import Foundation

struct Review: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    var requestId: String
    var reviewerId: String  // The user who submitted the review (can be requester OR swiper)
    var revieweeId: String  // The user being reviewed (can be swiper OR requester)
    var rating: Int         // 1-5 stars
    var createdAt: Timestamp
    
    init(
        requestId: String,
        reviewerId: String,
        revieweeId: String,
        rating: Int
    ) {
        self.requestId = requestId
        self.reviewerId = reviewerId
        self.revieweeId = revieweeId
        self.rating = rating
        self.createdAt = Timestamp()
    }
} 