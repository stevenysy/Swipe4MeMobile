//
//  GroupedRequestsListView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/21/25.
//

import SwiftUI

/// A view that displays a list of requests grouped by day.
///
/// - Parameters:
///   - requests: The list of requests to display.
///   - cardView: A view builder that creates a card view for each request.
///   - emptyStateView: A view builder that creates a view to display when there are no requests.
struct GroupedRequestsListView<Content: View, EmptyContent: View>: View {
    let requests: [SwipeRequest]
    @ViewBuilder let cardView: (SwipeRequest) -> Content
    @ViewBuilder let emptyStateView: () -> EmptyContent

    private var groupedRequests: [Date: [SwipeRequest]] {
        Dictionary(grouping: requests) { request in
            Calendar.current.startOfDay(for: request.meetingTime.dateValue())
        }
    }

    private var sortedDays: [Date] {
        groupedRequests.keys.sorted()
    }

    var body: some View {
        Group {
            if requests.isEmpty {
                emptyStateView()
            } else {
                requestsListView
            }
        }
    }

    private var requestsListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedDays, id: \.self) { day in
                    daySectionView(for: day)
                }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }

    private func daySectionView(for day: Date) -> some View {
        Section {
            daySectionContent(for: day)
        } header: {
            daySectionHeader(for: day)
        }
    }

    private func daySectionHeader(for day: Date) -> some View {
        Text(
            day,
            format: .dateTime.weekday(.abbreviated).month(.twoDigits).day(.twoDigits)
        )
        .font(.headline)
        .padding(.top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }

    private func daySectionContent(for day: Date) -> some View {
        ForEach(groupedRequests[day] ?? []) { request in
            cardView(request)
        }
    }
} 