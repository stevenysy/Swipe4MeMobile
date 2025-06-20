//
//  CreateSwipeRequestView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/12/25.
//

import SwiftUI
import FirebaseCore

struct CreateSwipeRequestView: View {
    @State var request: SwipeRequest
    @State private var selectedTime = Date()
    @Environment(AuthenticationManager.self) var authManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Location")
                    Spacer()
                    Picker("", selection: $request.location) {
                        ForEach(DiningLocation.allCases) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Meeting Time")
                    Spacer()
                    DatePicker("Meeting Time", selection: $selectedTime, in: Date()...)
                }
                .frame(height: 50)
            }

        }
        .navigationTitle("Make a Swipe Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
//            ToolbarItem(placement: .topBarLeading) {
//                Button {
//                    print("Cancel button pressed") // TODO: Add navigation
//                } label : {
//                    Text("Cancel")
//                }
//            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    request.meetingTime = Timestamp(date: selectedTime)
                    request.requesterId = authManager.user?.uid ?? ""
                    
                    dump(request)
                    
                    Task {
                        SwipeRequestManager.shared.addSwipeRequestToDatabase(swipeRequest: request, isEdit: false)
                        dismiss()
                    }
                } label: {
                    Text("Submit")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateSwipeRequestView(request: SwipeRequest())
            .environment(AuthenticationManager())
    }
}
