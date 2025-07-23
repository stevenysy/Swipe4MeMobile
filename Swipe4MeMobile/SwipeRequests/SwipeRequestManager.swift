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
    
    // MARK: - Cloud Task Cancellation
    
    func cancelRequestTasks(for request: SwipeRequest) async -> Bool {
        guard let taskNames = request.cloudTaskNames else {
            print("No cloud tasks to cancel for request \(request.id ?? "unknown")")
            return true // Consider it successful if there are no tasks to cancel
        }
        
        // Extract task names into array, filtering out empty strings
        let validTaskNames = [
            taskNames.reminderTaskName,
            taskNames.statusUpdateTaskName
        ].compactMap { $0 }.filter { !$0.isEmpty }
        
        guard !validTaskNames.isEmpty else {
            print("No valid task names to cancel for request \(request.id ?? "unknown")")
            return true // Consider it successful if there's nothing to cancel
        }
        
        print("Cancelling \(validTaskNames.count) tasks for request \(request.id ?? "unknown")")
        
        do {
            let result = try await callCancelTasksFunction(taskNames: validTaskNames)
            
            // Check if cancellation was successful
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool {
                
                if success {
                    print("Successfully cancelled \(validTaskNames.count) tasks for request \(request.id ?? "unknown")")
                    
                    // Log detailed results if available
                    if let summary = data["summary"] as? [String: Any],
                       let cancelled = summary["cancelled"] as? Int,
                       let notFound = summary["notFound"] as? Int,
                       let errors = summary["errors"] as? Int {
                        print("Cancellation summary: \(cancelled) cancelled, \(notFound) not found, \(errors) errors")
                    }
                    
                    return true
                } else {
                    print("Cloud Function reported failure for task cancellation")
                    return false
                }
            } else {
                print("Invalid response format from cancelCloudTasks function")
                return false
            }
        } catch {
            print("Failed to cancel cloud tasks for request \(request.id ?? "unknown"): \(error)")
            return false
        }
    }
    
    private func callCancelTasksFunction(taskNames: [String]) async throws -> HTTPSCallableResult {
        let functions = Functions.functions()
        let cancelFunction = functions.httpsCallable("cancelCloudTasks")
        
        // Call the function with task names array
        let data: [String: Any] = [
            "taskNames": taskNames
        ]
        
        do {
            let result = try await cancelFunction.call(data)
            print("Cancel tasks function called successfully")
            return result
        } catch {
            let nsError = error as NSError
            throw CloudTaskError.apiError(
                statusCode: nsError.code,
                message: nsError.localizedDescription
            )
        }
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
    
    /// Reschedules Cloud Tasks when a request's meeting time changes
    /// - Parameters:
    ///   - originalRequest: The request with the old meeting time and existing tasks
    ///   - updatedRequest: The request with the new meeting time
    func rescheduleCloudTasks(from originalRequest: SwipeRequest, to updatedRequest: SwipeRequest) async {
        print("Meeting time changed for scheduled request \(originalRequest.id ?? "unknown"), rescheduling Cloud Tasks...")
        
        // Cancel existing tasks before updating the request
        let tasksCancelled = await cancelRequestTasks(for: originalRequest)
        
        if tasksCancelled {
            print("Successfully cancelled existing tasks for request \(originalRequest.id ?? "unknown")")
            
            // Update the request in database first (without task names, they'll be updated when scheduling)
            var requestToUpdate = updatedRequest
            requestToUpdate.cloudTaskNames = nil // Clear old task names
            
            guard let requestId = requestToUpdate.id else {
                errorMessage = "Invalid request ID for rescheduling tasks"
                return
            }
            
            do {
                try db.collection("swipeRequests").document(requestId).setData(from: requestToUpdate)
                
                // Schedule new tasks with the updated meeting time
                let newTaskNames = await scheduleCloudTaskForRequest(
                    requestId: requestId, 
                    meetingTime: requestToUpdate.meetingTime
                )
                
                if newTaskNames != nil {
                    print("Successfully rescheduled Cloud Tasks for request \(requestId)")
                } else {
                    print("Failed to reschedule Cloud Tasks for request \(requestId)")
                }
            } catch {
                errorMessage = "Failed to update request during task rescheduling: \(error.localizedDescription)"
                print("Error updating request during rescheduling: \(error)")
            }
            
        } else {
            print("Failed to cancel existing tasks for request \(originalRequest.id ?? "unknown"), proceeding with request update anyway")
            
            // Still update the request even if task cancellation failed
            guard let requestId = updatedRequest.id else {
                errorMessage = "Invalid request ID for applying changes"
                return
            }
            
            do {
                try db.collection("swipeRequests").document(requestId).setData(from: updatedRequest)
            } catch {
                errorMessage = "Failed to update request: \(error.localizedDescription)"
                print("Error updating request: \(error)")
            }
        }
    }
    
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
