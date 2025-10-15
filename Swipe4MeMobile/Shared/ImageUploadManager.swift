//
//  ImageUploadManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 10/15/25.
//

import FirebaseStorage
import FirebaseFirestore
import UIKit

@MainActor
final class ImageUploadManager {
    static let shared = ImageUploadManager()
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    private init() {}
    
    enum UploadError: LocalizedError {
        case invalidUserId
        case imageConversionFailed
        case uploadFailed(Error)
        case urlRetrievalFailed
        case firestoreUpdateFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidUserId:
                return "User ID is invalid"
            case .imageConversionFailed:
                return "Failed to convert image"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .urlRetrievalFailed:
                return "Failed to retrieve download URL"
            case .firestoreUpdateFailed(let error):
                return "Failed to update profile: \(error.localizedDescription)"
            }
        }
    }
    
    /// Uploads a profile picture to Firebase Storage and updates the user's Firestore document
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's ID
    /// - Returns: The download URL of the uploaded image
    func uploadProfilePicture(image: UIImage, userId: String) async throws -> String {
        guard !userId.isEmpty else {
            throw UploadError.invalidUserId
        }
        
        // Compress and resize the image
        guard let imageData = compressImage(image) else {
            throw UploadError.imageConversionFailed
        }
        
        // Create storage reference
        let storageRef = storage.reference()
        let profilePicRef = storageRef.child("profilePictures/\(userId)/profile.jpg")
        
        // Upload the image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await profilePicRef.putDataAsync(imageData, metadata: metadata)
            print("✅ Image uploaded successfully")
        } catch {
            print("❌ Upload failed: \(error.localizedDescription)")
            throw UploadError.uploadFailed(error)
        }
        
        // Get download URL
        let downloadURL: URL
        do {
            downloadURL = try await profilePicRef.downloadURL()
            print("✅ Download URL retrieved: \(downloadURL.absoluteString)")
        } catch {
            print("❌ Failed to get download URL: \(error.localizedDescription)")
            throw UploadError.urlRetrievalFailed
        }
        
        // Update Firestore
        do {
            try await db.collection("users").document(userId).updateData([
                "profilePictureUrl": downloadURL.absoluteString
            ])
            print("✅ Firestore updated with new profile picture URL")
        } catch {
            print("❌ Failed to update Firestore: \(error.localizedDescription)")
            throw UploadError.firestoreUpdateFailed(error)
        }
        
        return downloadURL.absoluteString
    }
    
    /// Compresses and resizes an image to optimize for profile pictures
    /// - Parameter image: The original UIImage
    /// - Returns: Compressed JPEG data
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize to max 500x500 while maintaining aspect ratio
        let maxSize: CGFloat = 500
        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        
        let newSize: CGSize
        if scale < 1 {
            newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            newSize = image.size
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Compress to JPEG with 0.7 quality (good balance between size and quality)
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
}

