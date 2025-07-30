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
    var cloudTaskNames: CloudTaskNames?
    var requesterReviewCompleted: Bool = false
    var swiperReviewCompleted: Bool = false

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
        self.cloudTaskNames = nil
        self.requesterReviewCompleted = false
        self.swiperReviewCompleted = false
        self.createdAt = Timestamp()
    }
    
    /// Gets the other user ID in this request (the one that isn't the current user)
    /// - Parameter currentUserId: The current user's ID
    /// - Returns: The other user's ID (either requesterId or swiperId)
    func getOtherUserId(currentUserId: String) -> String {
        return currentUserId == requesterId ? swiperId : requesterId
    }
    
    /// Checks if the specified user has completed their review
    /// - Parameter userId: The user ID to check
    /// - Returns: True if the user has completed their review, false otherwise
    func hasUserCompletedReview(userId: String) -> Bool {
        if userId == requesterId {
            return requesterReviewCompleted
        } else if userId == swiperId {
            return swiperReviewCompleted
        }
        return false
    }
    
    /// Checks if both parties have completed their reviews
    /// - Returns: True if both requester and swiper have completed reviews
    func bothPartiesCompletedReviews() -> Bool {
        return requesterReviewCompleted && swiperReviewCompleted
    }
    
    /// Checks if we're waiting for the other party's review (current user completed, other hasn't)
    /// - Parameter currentUserId: The current user's ID
    /// - Returns: True if current user completed but other party hasn't
    func isWaitingForOtherPartyReview(currentUserId: String) -> Bool {
        let currentUserCompleted = hasUserCompletedReview(userId: currentUserId)
        let otherUserId = getOtherUserId(currentUserId: currentUserId)
        let otherUserCompleted = hasUserCompletedReview(userId: otherUserId)
        
        return currentUserCompleted && !otherUserCompleted
    }
}

enum RequestStatus: String, Codable, CaseIterable {
    case open
    case scheduled
    case inProgress
    case awaitingReview
    case complete
    case canceled

    var displayName: String {
        switch self {
        case .open:
            return "Open"
        case .scheduled:
            return "Scheduled"
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
        case .scheduled: .cyan
        case .inProgress: .blue
        case .awaitingReview: .orange
        case .complete: .purple
        case .canceled: .red
        }
    }
    
    /// Determines if changes to this request require approval from the other party
    var requiresApprovalForChanges: Bool {
        switch self {
        case .open:
            return false // Free edits for open requests
        case .scheduled, .inProgress:
            return true // Both parties need approval for scheduled/in-progress requests
        case .awaitingReview, .complete, .canceled:
            return false // No edits allowed for these statuses
        }
    }
}

// MARK: - Change Proposal Models

struct ChangeProposal: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    let requestId: String
    let proposedById: String // User ID of who proposed the change
    let proposedLocation: DiningLocation?
    let proposedMeetingTime: Timestamp?
    var status: ProposalStatus
    let createdAt: Timestamp
    var respondedAt: Timestamp?
    var respondedById: String? // User ID of who responded (accepted/declined)
    
    init(
        requestId: String,
        proposedById: String,
        proposedLocation: DiningLocation? = nil,
        proposedMeetingTime: Timestamp? = nil,
        status: ProposalStatus = .pending
    ) {
        self.requestId = requestId
        self.proposedById = proposedById
        self.proposedLocation = proposedLocation
        self.proposedMeetingTime = proposedMeetingTime
        self.status = status
        self.createdAt = Timestamp()
    }
    
    /// Checks if the proposal has any actual changes
    func hasChanges(comparedTo request: SwipeRequest) -> Bool {
        if let proposedLocation = proposedLocation, proposedLocation != request.location {
            return true
        }
        if let proposedMeetingTime = proposedMeetingTime, proposedMeetingTime != request.meetingTime {
            return true
        }
        return false
    }
    
    /// Gets a human-readable description of the proposed changes
    func getChangesDescription(comparedTo request: SwipeRequest) -> String {
        var changes: [String] = []
        
        if let proposedLocation = proposedLocation, proposedLocation != request.location {
            changes.append("Location: \(request.location.rawValue) → \(proposedLocation.rawValue)")
        }
        
        if let proposedMeetingTime = proposedMeetingTime, proposedMeetingTime != request.meetingTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let currentDateTime = formatter.string(from: request.meetingTime.dateValue())
            let newDateTime = formatter.string(from: proposedMeetingTime.dateValue())
            changes.append("Time: \(currentDateTime) → \(newDateTime)")
        }
        
        return changes.joined(separator: "\n")
    }
}

enum ProposalStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: .orange
        case .accepted: .green
        case .declined: .red
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

// MARK: - Cloud Task Names

struct CloudTaskNames: Codable, Equatable, Hashable {
    let reminderTaskName: String?
    let statusUpdateTaskName: String?
    
    init(reminderTaskName: String?, statusUpdateTaskName: String?) {
        self.reminderTaskName = reminderTaskName
        self.statusUpdateTaskName = statusUpdateTaskName
    }
}
