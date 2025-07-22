//
//  StarRatingView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/19/25.
//

import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    let maxRating: Int = 5
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { index in
                Button(action: {
                    rating = index
                }) {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundColor(index <= rating ? .yellow : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: rating)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Interactive Star Rating")
            .font(.headline)
        
        StarRatingView(rating: .constant(0))
        StarRatingView(rating: .constant(3))
        StarRatingView(rating: .constant(5))
    }
    .padding()
} 