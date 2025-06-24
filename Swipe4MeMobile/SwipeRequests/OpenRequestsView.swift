//
//  OpenRequestsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/16/25.
//

import SwiftUI
import FirebaseFirestore

struct OpenRequestsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @FirestoreQuery(
        collectionPath: "swipeRequests",
        predicates: [
            .where("status", isEqualTo: "open"),
            .where("meetingTime", isGreaterThan: Date()),
            .order(by: "meetingTime", descending: false)
        ],
        animation: .default
    ) var requests: [SwipeRequest]
    @State private var expandedRequestId: String?
    
    private var filteredRequests: [SwipeRequest] {
        guard let userId = authManager.user?.uid else {
            return []
        }
        return requests.filter { $0.requesterId != userId }
    }
    
    var body: some View {
        VStack {
            Text("Open Requests")
                .font(.largeTitle.bold())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if filteredRequests.isEmpty {
                ContentUnavailableView(
                    "No Open Requests",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Check back later for new requests!")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredRequests) { request in
                            OpenRequestCardView(
                                request: request,
                                isExpanded: expandedRequestId == request.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                    if expandedRequestId == request.id {
                                        expandedRequestId = nil
                                    } else {
                                        expandedRequestId = request.id
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: expandedRequestId)
            }
        }
    }
}

#Preview {
    OpenRequestsView()
        .environment(AuthenticationManager())
}
