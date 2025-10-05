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
    @State private var tipAmountText = ""
    @State private var showTipSection = false
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
            
            Section {
                HStack {
                    Text("Add Tip")
                    Spacer()
                    Toggle("", isOn: $showTipSection)
                }
                
                if showTipSection {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                        TextField("0.00", text: $tipAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            } footer: {
                Text("Optional tip to incentivize swipers. You'll coordinate payment details directly with your swiper.")
            }

        }
        .navigationTitle("Make a Swipe Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    request.meetingTime = Timestamp(date: selectedTime)
                    request.requesterId = authManager.user?.uid ?? ""
                    
                    // Set tip amount if provided
                    if showTipSection, let tipAmount = Double(tipAmountText), tipAmount > 0 {
                        request.tipAmount = tipAmount
                    } else {
                        request.tipAmount = nil
                    }
                    
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
