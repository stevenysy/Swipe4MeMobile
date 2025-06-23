//
//  OpenRequestsView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/16/25.
//

import SwiftUI
import FirebaseFirestore

struct OpenRequestsView: View {
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
    
    var body: some View {
        VStack {
            Text("Open Requests")
                .font(.largeTitle.bold())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            if requests.isEmpty {
                Spacer()
                Text("No requests found")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(requests) { request in
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
}
