//
//  SwipeRequestCardView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import SwiftUI

struct SwipeRequestCardView: View {
    let request: SwipeRequest

    var body: some View {
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
    Group {
        if let request = SwipeRequest.mockRequests.first {
            SwipeRequestCardView(request: request)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
