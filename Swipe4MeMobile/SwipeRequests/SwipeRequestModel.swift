//
//  SwipeRequestModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/12/25.
//

import FirebaseFirestore
import SwiftUI

struct SwipeRequest: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    var requesterId: String
    var swiperId: String
    var location: DiningLocation
    var meetingTime: Timestamp
    var status: RequestStatus

    let createdAt: Timestamp

    init(
        requesterId: String = "", swiperId: String = "", location: DiningLocation = .commons,
        meetingTime: Timestamp = Timestamp(), status: RequestStatus = .open
    ) {
        self.requesterId = requesterId
        self.swiperId = swiperId
        self.location = location
        self.meetingTime = meetingTime
        self.status = status
        self.createdAt = Timestamp()
    }
}

enum RequestStatus: String, Codable, CaseIterable {
    case open
    case inProgress
    case awaitingReview
    case complete
    case canceled

    var displayName: String {
        switch self {
        case .open:
            return "Open"
        case .inProgress:
            return "In Progress"
        case .awaitingReview:
            return "Awaiting Review"
        case .complete:
            return "Complete"
        case .canceled:
            return "Canceled"
        }
    }
}

extension RequestStatus {
    var color: Color {
        switch self {
        case .open: .green
        case .inProgress: .blue
        case .awaitingReview: .orange
        case .complete: .purple
        case .canceled: .red
        }
    }
}

enum DiningLocation: String, CaseIterable, Identifiable, Codable {
    case commons = "Commons"
    case ebi = "EBI"
    case rothschild = "Rothschild"
    case zeppos = "Zeppos"
    case kissam = "Kissam"
    case rand = "Rand"
    case randPizzaKitchen = "Rand Pizza Kitchen"
    case pub = "The Pub"
    case vandyBlenz = "VandyBlenz"
    case carmichael = "Carmichael"
    case wasabi = "Wasabi"
    case localJava = "Local Java"
    case grins = "Grin's Vegetarian Cafe"
    case suziesBlair = "Suzies Blair"
    case suziesFGH = "Suzies FGH"
    case suziesMRB3 = "Suzies MRB3"
    case suziesCentral = "Suzies Central"
    case branscombMunchie = "Branscomb Munchie"
    case commonsMunchie = "Commons Munchie"
    case highlandMunchie = "Highland Munchie"
    case kissamMunchie = "Kissam Munchie"

    var id: String { self.rawValue }
}
