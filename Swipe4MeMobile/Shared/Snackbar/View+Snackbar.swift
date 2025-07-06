import SwiftUI

/// A view modifier that overlays a snackbar view when a snackbar is presented.
private struct SnackbarModifier: ViewModifier {
    private let manager = SnackbarManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let snackbar = manager.currentSnackbar {
                    SnackbarView(snackbar: snackbar)
                        .onTapGesture {
                            manager.dismiss()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.currentSnackbar)
    }
}

extension View {
    /// Attaches the snackbar system to this view.
    /// - Returns: A view that can present snackbars.
    func snackbar() -> some View {
        modifier(SnackbarModifier())
    }
}
