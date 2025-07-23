//
//  SwipeRequestManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/12/25.
//

import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import Foundation

enum CloudTaskError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        }
    }
}

@Observable
@MainActor
final class SwipeRequestManager {
    static let shared = SwipeRequestManager()
    let db = Firestore.firestore()
    var errorMessage = ""

    func addSwipeRequestToDatabase(swipeRequest: SwipeRequest, isEdit: Bool) {
        do {
            if isEdit, let requestId = swipeRequest.id {
                try db.collection("swipeRequests").document(requestId).setData(from: swipeRequest)
            } else {
                try db.collection("swipeRequests").addDocument(from: swipeRequest)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Creates a new swipe request and returns it with its generated ID
    /// - Parameter swipeRequest: The SwipeRequest to create
    /// - Returns: The created SwipeRequest with its ID, or nil if creation failed
    func createSwipeRequest(_ swipeRequest: SwipeRequest) async -> SwipeRequest? {
        do {
            let documentRef = try db.collection("swipeRequests").addDocument(from: swipeRequest)
            
            // Return the request with the generated ID
            var requestWithId = swipeRequest
            requestWithId.id = documentRef.documentID
            
            print("Created swipe request with ID: \(documentRef.documentID)")
            return requestWithId
            
        } catch {
            print("Error creating swipe request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Deletes a request from Firestore and updates `errorMessage` on failure.
    ///
    /// - Parameter request: The `SwipeRequest` to remove.
    func deleteRequest(_ request: SwipeRequest) {
        guard let id = request.id else {
            self.errorMessage = "Request has no valid document ID."
            return
        }

        db.collection("swipeRequests").document(id).delete { error in
            if let error = error {
                self.errorMessage = error.localizedDescription   // <- Triggers alert
            } else {
                self.errorMessage = ""   // Clear any previous error
            }
        }
    }

    func markRequestAsSwiped(request: SwipeRequest) {
        guard let id = request.id else {
            self.errorMessage = "Request has no valid document ID."
            return
        }
        
        db.collection("swipeRequests").document(id).updateData([
            "status": RequestStatus.awaitingReview.rawValue
        ]) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription   // <- Triggers alert
            } else {
                self.errorMessage = ""   // Clear any previous error
            }
        }
    }

    func cancelRequest(request: SwipeRequest) {
        guard let id = request.id else {
            self.errorMessage = "Request has no valid document ID."
            return
        }

        db.collection("swipeRequests").document(id).updateData([
            "status": RequestStatus.canceled.rawValue
        ]) { error in
            print("Error cancelling request: \(error?.localizedDescription ?? "Unknown error")")
            if let error = error {
                self.errorMessage = error.localizedDescription   // <- Triggers alert
            } else {
                self.errorMessage = ""   // Clear any previous error
            }
        }
    }
    
    func cancelRequestAsSwiper(request: SwipeRequest) {
        guard let id = request.id else {
            self.errorMessage = "Request has no valid document ID."
            return
        }
        
        let newStatus: RequestStatus
        var updateData: [String: Any] = [:]
        
        switch request.status {
        case .scheduled:
            newStatus = .open
            updateData["status"] = newStatus.rawValue
            updateData["swiperId"] = ""  // Clear swiper ID when reverting to open
        case .inProgress:
            newStatus = .canceled
            updateData["status"] = newStatus.rawValue
            // Don't clear swiper ID when canceling - keep for record keeping
        default:
            newStatus = .canceled
            updateData["status"] = newStatus.rawValue
        }

        db.collection("swipeRequests").document(id).updateData(updateData) { error in
            print("Error cancelling request as swiper: \(error?.localizedDescription ?? "Unknown error")")
            if let error = error {
                self.errorMessage = error.localizedDescription   // <- Triggers alert
            } else {
                self.errorMessage = ""   // Clear any previous error
            }
        }
    }
    
    // MARK: - Cloud Task Scheduling
    
    func scheduleCloudTaskForRequest(requestId: String, meetingTime: Timestamp) async -> CloudTaskNames? {
        do {
            let result = try await callScheduleTaskFunction(requestId: requestId, meetingTime: meetingTime)
            
            // Extract task names from result
            if let data = result.data as? [String: Any],
               let reminderTaskName = data["reminderTaskName"] as? String,
               let statusUpdateTaskName = data["statusUpdateTaskName"] as? String {
                
                let taskNames = CloudTaskNames(
                    reminderTaskName: reminderTaskName,
                    statusUpdateTaskName: statusUpdateTaskName
                )
                
                // Update the request with task names
                do {
                    try await updateRequestWithTaskNames(requestId: requestId, taskNames: taskNames)
                    print("Successfully stored task names for request \(requestId)")
                    return taskNames
                } catch {
                    print("Failed to store task names: \(error)")
                    // Still return task names even if storage failed
                    return taskNames
                }
            } else {
                print("Failed to extract task names from Cloud Function response")
                return nil
            }
        } catch {
            print("Failed to schedule cloud task: \(error)")
            return nil
        }
    }
    
    private func updateRequestWithTaskNames(requestId: String, taskNames: CloudTaskNames) async throws {
        let updateData: [String: Any] = [
            "cloudTaskNames": [
                "reminderTaskName": taskNames.reminderTaskName ?? "",
                "statusUpdateTaskName": taskNames.statusUpdateTaskName ?? ""
            ]
        ]
        
        try await db.collection("swipeRequests").document(requestId).updateData(updateData)
    }
    
    private func callScheduleTaskFunction(requestId: String, meetingTime: Timestamp) async throws -> HTTPSCallableResult {
        // Use Firebase Functions SDK - much cleaner!
        let functions = Functions.functions()
        let scheduleFunction = functions.httpsCallable("scheduleRequestStatusUpdate")
        
        // Convert Timestamp to ISO string
        let scheduleTime = meetingTime.dateValue()
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let meetingTimeString = iso8601Formatter.string(from: scheduleTime)
        
        // Call the function with data
        let data: [String: String] = [
            "requestId": requestId,
            "meetingTime": meetingTimeString
        ]
        
        do {
            let result = try await scheduleFunction.call(data)
            print("Task scheduled successfully: \(result.data)")
            return result
        } catch {
            let nsError = error as NSError
            throw CloudTaskError.apiError(
                statusCode: nsError.code, 
                message: nsError.localizedDescription
            )
        }
    }
    
    // MARK: - Change Proposals
    
    /// Creates a change proposal and returns the proposal ID
    func createChangeProposal(
        for request: SwipeRequest,
        proposedLocation: DiningLocation?,
        proposedMeetingTime: Timestamp?,
        proposedById: String
    ) async throws -> String {
        guard let requestId = request.id else {
            throw CloudTaskError.invalidResponse
        }
        
        // Create the proposal
        let proposal = ChangeProposal(
            requestId: requestId,
            proposedById: proposedById,
            proposedLocation: proposedLocation,
            proposedMeetingTime: proposedMeetingTime
        )
        
        // Validate changes
        guard proposal.hasChanges(comparedTo: request) else {
            throw CloudTaskError.invalidResponse // No changes to propose
        }
        
        // Save proposal to database and return the ID
        let proposalRef = try db.collection("changeProposals").addDocument(from: proposal)
        return proposalRef.documentID
    }
}
