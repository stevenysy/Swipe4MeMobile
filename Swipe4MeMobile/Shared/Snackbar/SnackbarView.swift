import SwiftUI

/// A view that displays a single snackbar message.
struct SnackbarView: View {
    let snackbar: Snackbar

    var body: some View {
        HStack(spacing: 16) {
            // Style Indicator
            snackbar.style.color
                .frame(width: 6)

            // Icon
            Image(systemName: snackbar.style.iconSystemName)
                .foregroundColor(snackbar.style.color)
                .font(.title2)

            // Text
            Text(snackbar.title)
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
        .frame(height: 60)
        .background(.background)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        SnackbarView(snackbar: Snackbar(title: "Request Deleted Successfully", style: .success))
        SnackbarView(snackbar: Snackbar(title: "Unable to connect to servers", style: .error))
        SnackbarView(snackbar: Snackbar(title: "Your request is now pending", style: .info))
        SnackbarView(snackbar: Snackbar(title: "Please check your input", style: .warning))
    }
    .padding()
    .background(Color(.systemGray6))
}
