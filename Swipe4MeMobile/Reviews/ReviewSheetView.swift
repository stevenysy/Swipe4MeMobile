//
//  ReviewSheetView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import SwiftUI

struct ReviewSheetView: View {
    let request: SwipeRequest
    
    @State private var selectedRating: Int = 0
    @State private var isSubmitting = false
    @State private var revieweeName: String = "the other person"
    @State private var isLoadingName = true
    @Environment(\.dismiss) private var dismiss
    
    private let reviewManager = ReviewManager.shared
    private let snackbarManager = SnackbarManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    Text("Rate Your Experience")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if isLoadingName {
                        Text("How was your swipe experience?")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("How was your swipe experience with \(revieweeName)?")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                
                // Star Rating
                StarRatingView(rating: $selectedRating)
                    .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: submitReview) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Review")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRating == 0 || isSubmitting)
                    
                    Button("Remind Me Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            fetchRevieweeName()
        }
    }
    
    private func submitReview() {
        guard selectedRating > 0, let requestId = request.id else { return }
        
        isSubmitting = true
        
        Task {
            let success = await reviewManager.submitReview(
                requestId: requestId,
                revieweeId: request.swiperId,
                rating: selectedRating
            )
            
            await MainActor.run {
                isSubmitting = false
                
                if success {
                    snackbarManager.show(title: "Review submitted! Thanks for your feedback.", style: .success)
                    NavigationCoordinator.shared.clearReviewSheet(reviewSubmitted: true)
                } else {
                    snackbarManager.show(title: "Failed to submit review: \(reviewManager.errorMessage)", style: .error)
                }
            }
        }
    }
    
    private func fetchRevieweeName() {
        let currentUserId = UserManager.shared.userID
        
        // Determine who is being reviewed based on current user's role
        let revieweeId: String
        if currentUserId == request.requesterId {
            // Current user is the requester, so they're reviewing the swiper
            revieweeId = request.swiperId
        } else {
            // Current user is the swiper, so they're reviewing the requester
            revieweeId = request.requesterId
        }
        
        Task {
            if let user = await UserManager.shared.getUser(userId: revieweeId) {
                revieweeName = "\(user.firstName) \(user.lastName)"
                isLoadingName = false
            } else {
                revieweeName = "the other person"
                isLoadingName = false
            }
        }
    }
}

#Preview {
    ReviewSheetView(
        request: SwipeRequest.mockRequests.first!
    )
}
