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
        VStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header (styled to match SwipeRequestCardView)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(request.location.rawValue)
                            .font(.headline)
                        Text("Meeting at: \(request.meetingTime.dateValue(), style: .time)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    statusPill(for: request.status)
                }

                Divider()

                Text("Additional Details")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Swiper:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(request.swiperId.isEmpty ? "Not assigned" : request.swiperId)
                    }

                    HStack {
                        Text("Created:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(request.createdAt.dateValue(), style: .relative)
                    }
                }
                .font(.body)

                Button("Edit Request") {
                    onEdit(request)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .matchedGeometryEffect(id: request.id, in: animation)
        }
        .padding(30)  // This padding centers the card and stops it from filling the screen
        .onTapGesture {
            // To prevent taps from passing through to the background overlay
        }
    }

    private func onEdit(_ request: SwipeRequest) {
        print("editing swipe request with id \(String(describing: request.id))")
    }

    // Copied from SwipeRequestCardView to ensure visual consistency
    private func statusPill(for status: RequestStatus) -> some View {
        Text(status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(for: status).opacity(0.15))
            .foregroundColor(statusColor(for: status))
            .cornerRadius(8)
    }

    private func statusColor(for status: RequestStatus) -> Color {
        switch status {
        case .open: .green
        case .inProgress: .blue
        case .awaitingReview: .orange
        case .complete: .purple
        case .canceled: .red
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
            ZStack {
                Color.gray.opacity(0.2).ignoresSafeArea()
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
    }

    return PreviewWrapper()
}
