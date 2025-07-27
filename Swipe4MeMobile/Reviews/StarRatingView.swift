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
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(1...maxRating, id: \.self) { index in
                    Button(action: {
                        rating = index
                    }) {
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .font(.largeTitle)
                            .foregroundColor(index <= rating ? .yellow : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .animation(.easeInOut(duration: 0.2), value: rating)
            
            // Reserved space for description - always present but invisible when rating is 0
            Text(ratingDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .opacity(rating > 0 ? 1 : 0)
                .frame(height: 20) // Reserve consistent height
        }
    }
    
    private var ratingDescription: String {
        switch rating {
        case 1: return "Poor experience"
        case 2: return "Below expectations"
        case 3: return "Good experience"
        case 4: return "Great experience"
        case 5: return "Excellent experience!"
        default: return ""
        }
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
