//
//  MyRequestsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/18/25.
//

import FirebaseFirestore
import SwiftUI

// A view that displays the current user's swipe requests.
// It uses the `AuthenticationManager` from the environment to identify the user
// and fetches the relevant requests from Firestore.
struct MyRequestsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    
    @State private var selectedRequest: SwipeRequest?
    
    var body: some View {
        NavigationStack {
            // Since MasterView ensures this view is only shown for authenticated users,
            // we can safely access the user's ID.
            if let userId = authManager.user?.uid {
                ZStack {
                    MyRequestsListView(
                        requesterId: userId, selectedRequest: $selectedRequest
                    )
                    .padding(.top)
                    .blur(radius: selectedRequest != nil ? 20 : 0)  // Blur when a card is selected
                    .toolbar {
                        if selectedRequest == nil {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                NavigationLink {
                                    CreateSwipeRequestView(request: SwipeRequest())
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .padding(.top)
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarLeading) {
                            Text("My Requests")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                                .padding(.top)
                        }
                    }
                    
                    // Blur the background when a request is selected
                    if selectedRequest != nil {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                    selectedRequest = nil
                                }
                            }
                    }
                    
                    if let selectedRequest {
                        SwipeRequestCardView(request: selectedRequest, isExpanded: true)
                            .padding(30)
                            .onTapGesture {
                                // To prevent taps from passing through to the background overlay
                            }
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: selectedRequest)
            } else {
                // A fallback for the unlikely case that the user ID is unavailable.
                // This state should not be reached in normal app flow.
                ContentUnavailableView(
                    "Cannot Load Requests",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Could not retrieve your user information.")
                )
                .navigationTitle("My Requests")
            }
        }
    }
    
    // A computed property for the empty state view.
    // The @ViewBuilder is not strictly necessary here but is good practice.
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Requests Found",
            systemImage: "doc.text.magnifyingglass",
            description: Text("You haven't made any swipe requests yet.")
        )
    }
}

// A private view responsible for querying and displaying the list of requests
// for a specific user.
private struct MyRequestsListView: View {
    @FirestoreQuery var requests: [SwipeRequest]
    
    @Binding var selectedRequest: SwipeRequest?
    
    // Initializes the Firestore query to fetch requests for the given user ID.
    init(requesterId: String, selectedRequest: Binding<SwipeRequest?>) {
        // We initialize the query here because it depends on a dynamic value (requesterId).
        // The _requests syntax gives us access to the underlying FirestoreQuery
        // property wrapper so we can configure it when the view is created.
        self._requests = FirestoreQuery(
            collectionPath: "swipeRequests",
            predicates: [
                .where("requesterId", isEqualTo: requesterId),
                .order(by: "meetingTime", descending: false),
            ]
        )
        self._selectedRequest = selectedRequest
    }
    
    var body: some View {
        MyRequestsContentView(
            requests: requests, selectedRequest: $selectedRequest)
    }
}

private struct MyRequestsContentView: View {
    let requests: [SwipeRequest]
    
    @Binding var selectedRequest: SwipeRequest?
    
    // Group requests by the start of the day
    private var groupedRequests: [Date: [SwipeRequest]] {
        Dictionary(grouping: requests) { request in
            Calendar.current.startOfDay(for: request.meetingTime.dateValue())
        }
    }
    
    // Get the sorted list of days
    private var sortedDays: [Date] {
        groupedRequests.keys.sorted()
    }
    
    var body: some View {
        Group {
            if requests.isEmpty {
                ContentUnavailableView(
                    "No Requests Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("You haven't made any swipe requests yet.")
                )
            } else {
                requestsListView
            }
        }
    }
    
    // A computed property for the scrollable list of requests.
    private var requestsListView: some View {
        ScrollView {
            // Use LazyVStack for performance and pinned headers
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedDays, id: \.self) { day in
                    // Each day is its own section
                    daySectionView(for: day)
                }
            }
        }
        // Add horizontal padding to the entire scrollable area
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
    }
    
    // A method to build a section for a specific day.
    private func daySectionView(for day: Date) -> some View {
        Section {
            // Content of the section (the cards)
            daySectionContent(for: day)
        } header: {
            // Header for the section (the date)
            daySectionHeader(for: day)
        }
    }
    
    // A method to build the header for a day section.
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
    
    // A method to build the content (cards) for a day section.
    private func daySectionContent(for day: Date) -> some View {
        ForEach(groupedRequests[day] ?? []) { request in
            // Using the refactored card view
            SwipeRequestCardView(request: request, isExpanded: false)
                .opacity(selectedRequest?.id == request.id ? 0 : 1)
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        self.selectedRequest = request
                    }
                }
        }
    }
}

#Preview {
    // We create a wrapper to provide the necessary state for the preview.
    struct PreviewWrapper: View {
        @State private var selectedRequest: SwipeRequest?
        
        var body: some View {
            MyRequestsContentView(
                requests: SwipeRequest.mockRequests,
                selectedRequest: $selectedRequest
            )
        }
    }
    
    return NavigationStack {
        PreviewWrapper()
    }
    .environment(AuthenticationManager())
}
