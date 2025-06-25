//
//  Shimmer.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 6/20/25.
//

import SwiftUI

public struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration = 1.5
    var bounce = false

    public func body(content: Content) -> some View {
        content
            .modifier(
                AnimatedMask(phase: phase)
            )
            .animation(
                Animation.linear(duration: duration)
                    .repeatForever(autoreverses: bounce),
                value: phase
            )
            .onAppear { phase = 0.8 }
    }

    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0

        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }

        func body(content: Content) -> some View {
            content
                .mask(
                    GradientMask(phase: phase)
                        .scaleEffect(3)
                )
        }
    }

    struct GradientMask: View {
        let phase: CGFloat
        let centerColor = Color.black
        let edgeColor = Color.black.opacity(0.3)

        var body: some View {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: edgeColor, location: phase),
                    .init(color: centerColor, location:phase + 0.1),
                    .init(color: edgeColor, location: phase + 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

public extension View {
    @ViewBuilder
    func shimmering() -> some View {
        self.modifier(Shimmer())
    }
} 
