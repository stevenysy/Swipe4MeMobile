//
//  MyProfileSheet.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 10/12/25.
//

import SwiftUI
import PhotosUI

struct MyProfileSheet: View {
    let user: SFMUser
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar
                Group {
                    if isUploading {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                            ProgressView()
                        }
                    } else if let imageUrl = URL(string: user.profilePictureUrl) {
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
                
                // Error message
                if let uploadError = uploadError {
                    Text(uploadError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Change Profile Picture Button
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text(isUploading ? "Uploading..." : "Change profile picture")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isUploading)
                .onChange(of: selectedPhoto) { oldValue, newValue in
                    guard let newValue = newValue else { return }
                    
                    Task {
                        await handlePhotoSelection(newValue)
                    }
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
    
    private func handlePhotoSelection(_ photoItem: PhotosPickerItem) async {
        uploadError = nil
        isUploading = true
        
        defer {
            Task { @MainActor in
                isUploading = false
            }
        }
        
        do {
            // Load the image data
            guard let data = try await photoItem.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    uploadError = "Failed to load image data"
                }
                return
            }
            
            print("  - Data size: \(data.count) bytes (\(Double(data.count) / 1_048_576) MB)")
            
            // Convert to UIImage
            guard let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    uploadError = "Failed to convert image"
                }
                return
            }
            
            print("  - Image size: \(uiImage.size.width) x \(uiImage.size.height)")
            
            // Upload the image
            guard let userId = user.id else {
                await MainActor.run {
                    uploadError = "User ID not found"
                }
                return
            }
            
            let downloadURL = try await ImageUploadManager.shared.uploadProfilePicture(
                image: uiImage,
                userId: userId
            )
            
            print("✅ Profile picture uploaded successfully: \(downloadURL)")
            
            // The UserManager listener will automatically update the UI
            
        } catch {
            print("❌ Error uploading profile picture: \(error.localizedDescription)")
            await MainActor.run {
                if let uploadError = error as? ImageUploadManager.UploadError {
                    self.uploadError = uploadError.errorDescription
                } else {
                    self.uploadError = "Upload failed: \(error.localizedDescription)"
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

