//
//  DashboardUserInfoView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/11/25.
//

import SwiftUI

struct DashboardUserInfoView: View {
    let user: SFMUser
    
    var body: some View {
        HStack(spacing: 16) {
            // User Avatar
            Group {
                if let imageUrl = URL(string: user.profilePictureUrl) {
                    CachedAsyncImage(url: imageUrl) { image in
                        image.resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                }
            }
            
            // User Info Column
            VStack(alignment: .leading, spacing: 4) {
                // User Name
                Text("\(user.firstName) \(user.lastName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Rating
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    if let averageRating = user.averageRating,
                       user.totalReviews > 0 {
                        Text(String(format: "%.1f", averageRating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No reviews yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    DashboardUserInfoView(
        user: SFMUser(
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@vanderbilt.edu",
            profilePictureUrl: ""
        )
    )
    .padding()
} 