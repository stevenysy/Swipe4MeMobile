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
                ProgressView()
                Text("Loading User...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if let user = user {
                if let imageUrl = URL(string: user.profilePictureUrl) {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
                
                Text("\(user.firstName) \(user.lastName)")
                    .font(.body)
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