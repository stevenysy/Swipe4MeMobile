//
//  CreateSwipeRequestView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/12/25.
//

import SwiftUI

struct CreateSwipeRequestView: View {
    @State var request: SwipeRequest
    
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
        }
        .navigationTitle("Make a Swipe Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CreateSwipeRequestView(request: SwipeRequest())
}
