//
//  UserInfoView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import SwiftUI

struct UserInfoView: View {
    let userId: String

    @State private var user: SFMUser?
    @State private var isLoading = true

    var body: some View {
        HStack {
            if isLoading {
                skeletonView
            } else if let user = user {
                Group {
                    if let imageUrl = URL(string: user.profilePictureUrl) {
                        CachedAsyncImage(url: imageUrl) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(user.firstName) \(user.lastName)")
                        .font(.body)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                Text("User not assigned")
            }
        }
        .onAppear {
            fetchUser()
        }
    }

    private var skeletonView: some View {
        HStack {
            Circle()
                .frame(width: 40, height: 40)
            
            Text("Firstname Lastname")
                .font(.body)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private func fetchUser() {
        guard !userId.isEmpty else {
            isLoading = false
            user = nil
            return
        }
        
        Task {
            isLoading = true
            user = await UserManager.shared.getUser(userId: userId)
            isLoading = false
        }
    }
}

#Preview {
    VStack {
        UserInfoView(userId: "user_swiper_1")
        UserInfoView(userId: "")
    }
    .padding()
} 
