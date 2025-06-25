//
//  ImageCacheManager.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func get(forKey key: String) -> UIImage? {
        print("Getting image for key: \(key)")
        return cache.object(forKey: key as NSString)
    }

    func set(forKey key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
        print("Cached image for key: \(key)")
    }
} 
