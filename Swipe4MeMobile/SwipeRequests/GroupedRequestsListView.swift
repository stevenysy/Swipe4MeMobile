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

/// A specialized version of GroupedRequestsListView that encapsulates state management
/// for SwipeRequestCardView interactions (selection, deletion, etc.)
///
/// - Parameters:
///   - requests: The list of requests to display.
///   - userId: The current user's ID to determine if they are the requester or swiper.
///   - emptyStateView: A view builder that creates a view to display when there are no requests.
struct SwipeRequestGroupedListView<EmptyContent: View>: View {
    let requests: [SwipeRequest]
    let userId: String
    @ViewBuilder let emptyStateView: () -> EmptyContent
    
    @State private var selectedRequest: SwipeRequest?
    @State private var requestToDelete: SwipeRequest?
    @Environment(SnackbarManager.self) private var snackbarManager

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
                requestsListViewWithScrolling
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: selectedRequest)
        .alert(
            "Delete Request", isPresented: .constant(requestToDelete != nil),
            presenting: requestToDelete
        ) { request in
            Button("Delete", role: .destructive) {
                if let requestToDelete = requestToDelete {
                    SwipeRequestManager.shared.deleteRequest(requestToDelete)
                    snackbarManager.show(title: "Request Deleted", style: .success)
                }
                self.requestToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                self.requestToDelete = nil
            }
        } message: { request in
            Text(
                "Are you sure you want to delete this swipe request for \(request.location.rawValue) at \(request.meetingTime.dateValue(), style: .time)? This action cannot be undone."
            )
        }
    }
    
    private var requestsListViewWithScrolling: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(sortedDays, id: \.self) { day in
                        Section {
                            ForEach(groupedRequests[day] ?? []) { request in
                                SwipeRequestCardView(
                                    request: request,
                                    isExpanded: selectedRequest?.id == request.id,
                                    onDelete: {
                                        self.requestToDelete = request
                                    },
                                    onEdit: {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                            self.selectedRequest = nil
                                        }
                                    },
                                    isRequesterCard: request.requesterId == userId
                                )
                                .id(request.id) // Important: Give each card a unique ID for scrolling
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                        if self.selectedRequest?.id == request.id {
                                            self.selectedRequest = nil
                                        } else {
                                            self.selectedRequest = request
                                            // Scroll to the expanded card after a brief delay to allow the animation to start
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation(.easeInOut(duration: 0.5)) {
                                                    proxy.scrollTo(request.id, anchor: .center)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text(
                                day,
                                format: .dateTime.weekday(.abbreviated).month(.twoDigits).day(.twoDigits)
                            )
                            .font(.headline)
                            .padding(.top)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .background(Color(.systemGroupedBackground))
        }
    }
} 