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
                    DatePicker("Meeting Time", selection: $selectedTime, in: Date()...)
                }
                .frame(height: 50)
            }

        }
        .navigationTitle("Make a Swipe Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    request.meetingTime = Timestamp(date: selectedTime)
                    request.requesterId = authManager.user?.uid ?? ""
                    
                    dump(request)
                    
                    Task {
                        // Create the swipe request and get it back with the generated ID
                        if let createdRequest = await SwipeRequestManager.shared.createSwipeRequest(request) {
                            // Create the chat room for the new request (now with ID)
                            await ChatManager.shared.createChatRoom(for: createdRequest)
                            
                            SnackbarManager.shared.show(title: "Request created", style: .success)
                            dismiss()
                        } else {
                            SnackbarManager.shared.show(title: "Failed to create request", style: .error)
                        }
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
