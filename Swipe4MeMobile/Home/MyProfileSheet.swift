//
//  MyProfileSheet.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 10/12/25.
//

import SwiftUI

struct MyProfileSheet: View {
    let user: SFMUser
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar
                Group {
                    if let imageUrl = URL(string: user.profilePictureUrl) {
                        CachedAsyncImage(url: imageUrl) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 32)
                
                // Full Name
                Text("\(user.firstName) \(user.lastName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Rating
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.body)
                    
                    if let averageRating = user.averageRating,
                       user.totalReviews > 0 {
                        Text(String(format: "%.1f", averageRating))
                            .font(.body)
                            .foregroundColor(.primary)
                    } else {
                        Text("No reviews yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Change Profile Picture Button
                Button(action: {
                    // TODO: Handle profile picture change
                }) {
                    Text("Change profile picture")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MyProfileSheet(
        user: SFMUser(
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@vanderbilt.edu",
            profilePictureUrl: ""
        )
    )
}

