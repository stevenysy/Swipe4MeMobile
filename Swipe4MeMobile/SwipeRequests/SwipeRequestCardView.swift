//
//  SwipeRequestCardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import SwiftUI

struct SwipeRequestCardView: View {
    let request: SwipeRequest
    var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            if isExpanded {
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

                HStack {
                    Button("Edit") {
                        handleEdit(request)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Delete", role: .destructive) {
                        handleDelete(request)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func handleEdit(_ request: SwipeRequest) {
        print("editing swipe request with id \(String(describing: request.id))")
    }

    private func handleDelete(_ request: SwipeRequest) {
        print("deleting swipe request with id \(String(describing: request.id))")
    }

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
    VStack(spacing: 20) {
        if let request = SwipeRequest.mockRequests.first {
            SwipeRequestCardView(request: request, isExpanded: false)
            SwipeRequestCardView(request: request, isExpanded: true)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
