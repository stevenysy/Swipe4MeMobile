//
//  CachedAsyncImage.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        if let image = image {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .onAppear(perform: loadImage)
        }
    }

    private func loadImage() {
        guard let url = url else { return }
        let urlString = url.absoluteString

        if let cachedImage = ImageCacheManager.shared.get(forKey: urlString) {
            self.image = cachedImage
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageCacheManager.shared.set(forKey: urlString, image: uiImage)
                    self.image = uiImage
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
    }
} 