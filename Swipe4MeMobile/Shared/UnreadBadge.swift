//
//  UnreadBadge.swift
//  Swipe4MeMobile
//
//  Created by AI Assistant on 1/3/25.
//

import SwiftUI

struct UnreadBadge: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                
                if count <= 9 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("9+")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            Image(systemName: "message")
                .font(.title2)
                .overlay(
                    UnreadBadge(count: 1)
                        .offset(x: 8, y: -8)
                )
            
            Image(systemName: "message")
                .font(.title2)
                .overlay(
                    UnreadBadge(count: 5)
                        .offset(x: 8, y: -8)
                )
            
            Image(systemName: "message")
                .font(.title2)
                .overlay(
                    UnreadBadge(count: 12)
                        .offset(x: 8, y: -8)
                )
            
            Image(systemName: "message")
                .font(.title2)
                .overlay(
                    UnreadBadge(count: 0) // Should not show
                        .offset(x: 8, y: -8)
                )
        }
    }
    .padding()
} 