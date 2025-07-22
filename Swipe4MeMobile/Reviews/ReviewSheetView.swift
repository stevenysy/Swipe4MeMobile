//
//  ReviewSheetView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import SwiftUI

struct ReviewSheetView: View {
    let request: SwipeRequest
    let swiperName: String
    
    @State private var selectedRating: Int = 0
    @State private var isSubmitting = false
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
                    
                    Text("How was your swipe experience with \(swiperName)?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Star Rating
                VStack(spacing: 16) {
                    StarRatingView(rating: $selectedRating)
                    
                    if selectedRating > 0 {
                        Text(ratingDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private var ratingDescription: String {
        switch selectedRating {
        case 1: return "Poor experience"
        case 2: return "Below expectations"
        case 3: return "Good experience"
        case 4: return "Great experience"
        case 5: return "Excellent experience!"
        default: return ""
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
                    dismiss()
                } else {
                    snackbarManager.show(title: "Failed to submit review: \(reviewManager.errorMessage)", style: .error)
                }
            }
        }
    }
}

#Preview {
    ReviewSheetView(
        request: SwipeRequest.mockRequests.first!,
        swiperName: "John Smith"
    )
} 