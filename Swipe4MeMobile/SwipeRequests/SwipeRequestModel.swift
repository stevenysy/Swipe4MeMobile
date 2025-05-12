//
//  SwipeRequestModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/12/25.
//

import FirebaseFirestore

struct SwipeRequest: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    let requesterId: String
    var swiperId: String
    var location: DiningLocation
    var meetingTime: Timestamp
    var status: RequestStatus
    
    let createdAt: Timestamp
}

enum RequestStatus: Codable {
    case open
    case inProgress
    case awaitingReview
    case complete
    case canceled
}

enum DiningLocation: Codable {
    case commons
    case ebi
    case rothschild
    case zeppos
    case kissam
    case rand
    case randPizzaKitchen
    case pub
    case vandyBlenz
    case carmichael
    case wasabi
    case localJava
    case grinsVegetarianCafe
    case suziesBlair
    case suziesFGH
    case suziesMRB3
    case suziesCentral
    case branscombMunchie
    case commonsMunchie
    case highlandMunchie
    case kissamMunchie
}
