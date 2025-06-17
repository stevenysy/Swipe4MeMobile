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
    
    var body: some View {
        Text("Open Requests")
        
        if requests.isEmpty {
            Text("No requests found")
                .foregroundColor(.gray)
        }
        
        List {
            ForEach(requests, id: \.id) { request in
                VStack(alignment: .leading) {
                    Text("Meeting Time: \(request.meetingTime.dateValue().formatted())")
                    Text("Location: \(request.location)")
                    // Add more request details as needed
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    OpenRequestsView()
}
