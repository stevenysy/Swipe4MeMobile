//
//  RoleSelectionView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 7/24/24.
//

import SwiftUI

struct RoleSelectionView: View {
    @Binding var selectedRole: UserRole
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
//            Text("Switch View")
//                .font(.title2.bold())
//                .padding(.bottom)

            RoleOption(
                role: .requester,
                title: "Requester View",
                description: "Request help with swipes.",
                isSelected: selectedRole == .requester,
                action: {
                    selectedRole = .requester
                    dismiss()
                }
            )

            RoleOption(
                role: .swiper,
                title: "Swiper View",
                description: "Help others with their swipes.",
                isSelected: selectedRole == .swiper,
                action: {
                    selectedRole = .swiper
                    dismiss()
                }
            )

            Spacer()
        }
        .padding()
    }
}

private struct RoleOption: View {
    let role: UserRole
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .padding(.trailing)
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(description).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    RoleSelectionView(selectedRole: .constant(.requester))
} 
