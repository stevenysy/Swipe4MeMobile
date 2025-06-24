//
//  StatusPillView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import SwiftUI

struct StatusPillView: View {
    let status: RequestStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.15))
            .foregroundColor(status.color)
            .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 10) {
        ForEach(RequestStatus.allCases, id: \.self) { status in
            StatusPillView(status: status)
        }
    }
    .padding()
} 