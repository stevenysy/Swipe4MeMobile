//
//  MySwipeRequestDetailsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import SwiftUI

struct MySwipeRequestDetailsView: View {
    let request: SwipeRequest
    let animation: Namespace.ID
    @Binding var selectedRequest: SwipeRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // This is the anchor for our animation. It looks identical to the
                // card in the list, and the matchedGeometryEffect will animate
                // the transition from the list to this position.
                SwipeRequestCardView(request: request)
                    .matchedGeometryEffect(id: request.id, in: animation)
                    .onTapGesture {
                        dismiss()
                    }

                // Additional details that appear on expansion
                VStack(alignment: .leading, spacing: 20) {
                    Text("Additional Details")
                        .font(.title2.bold())
                        .padding(.top)

                    Label("Requester: You", systemImage: "person.fill")
                    Label("Offer: 1 Meal Swipe", systemImage: "gift.fill")
                    Label("Status: \(request.status.displayName)", systemImage: "info.circle.fill")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 50)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onTapGesture {  // Tap background to dismiss
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            selectedRequest = nil
        }
    }
}

#Preview {
    // This wrapper view is necessary to provide the state and namespace
    // that SwipeRequestDetailView needs to function.
    struct PreviewWrapper: View {
        @Namespace private var animation
        // We use @State to hold the selected request. We'll pre-populate it
        // so the detail view is visible when the preview loads.
        @State private var selectedRequest: SwipeRequest? = SwipeRequest.mockRequests.first

        var body: some View {
            // We show the detail view only if a request is selected.
            if let request = selectedRequest {
                MySwipeRequestDetailsView(
                    request: request,
                    animation: animation,
                    selectedRequest: $selectedRequest
                )
            } else {
                // This will show if you dismiss the detail view in the preview.
                Text("No request selected.")
            }
        }
    }

    return PreviewWrapper()
}
