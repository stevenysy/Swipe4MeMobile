//
//  SwipeRequestCardViewModel.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import FirebaseFirestore
import SwiftUI

@Observable
@MainActor
final class SwipeRequestCardViewModel {
    // MARK: - Published Properties
    var isEditing = false
    var editedLocation: DiningLocation = .commons
    var editedMeetingTime = Date()
    var requestToCancel: SwipeRequest?
    var requestToMarkSwiped: SwipeRequest?
    
    // MARK: - Dependencies
    private let swipeRequestManager = SwipeRequestManager.shared
    private let snackbarManager = SnackbarManager.shared
    
    // MARK: - Public Methods
    func handleEdit(for request: SwipeRequest) {
        editedLocation = request.location
        editedMeetingTime = request.meetingTime.dateValue()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = true
        }
    }
    
    func handleSubmit(for request: SwipeRequest) {
        var updatedRequest = request
        updatedRequest.location = editedLocation
        updatedRequest.meetingTime = Timestamp(date: editedMeetingTime)
        
        swipeRequestManager.addSwipeRequestToDatabase(
            swipeRequest: updatedRequest, isEdit: true)
        snackbarManager.show(title: "Request Updated", style: .success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = false
        }
    }
    
    func handleDelete(for request: SwipeRequest) {
        requestToCancel = request
    }
    
    func handleSwiped(for request: SwipeRequest) {
        requestToMarkSwiped = request
    }
    
    func confirmCancel() {
        guard let request = requestToCancel else { return }
        swipeRequestManager.cancelRequest(request: request)
        snackbarManager.show(title: "Request Cancelled", style: .success)
        requestToCancel = nil
    }
    
    func cancelDelete() {
        requestToCancel = nil
    }
    
    func confirmSwiped() {
        guard let request = requestToMarkSwiped else { return }
        swipeRequestManager.markRequestAsSwiped(request: request)
        snackbarManager.show(title: "Marked as Swiped!", style: .success)
        requestToMarkSwiped = nil
    }
    
    func cancelSwiped() {
        requestToMarkSwiped = nil
    }
    
    func cancelEditing() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isEditing = false
        }
    }
} 