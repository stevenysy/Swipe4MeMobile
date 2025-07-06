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
    
    func scheduleCloudTaskForRequest(requestId: String, meetingTime: Timestamp) {
        Task {
            do {
                try await callScheduleTaskFunction(requestId: requestId, meetingTime: meetingTime)
                print("Successfully scheduled cloud task for request \(requestId)")
            } catch {
                print("Failed to schedule cloud task: \(error)")
                // Note: We don't update errorMessage as this is a background operation
                // The main request operation has already succeeded
            }
        }
    }
    
    private func callScheduleTaskFunction(requestId: String, meetingTime: Timestamp) async throws {
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
        } catch {
            let nsError = error as NSError
            throw CloudTaskError.apiError(
                statusCode: nsError.code, 
                message: nsError.localizedDescription
            )
        }
    }
}
