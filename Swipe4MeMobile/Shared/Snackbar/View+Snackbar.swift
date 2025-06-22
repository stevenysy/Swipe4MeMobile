import SwiftUI

/// A view modifier that overlays a snackbar view when a snackbar is presented.
private struct SnackbarModifier: ViewModifier {
    let snackbar: Snackbar?
    let manager: SnackbarManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let snackbar {
                    SnackbarView(snackbar: snackbar)
                        .onTapGesture {
                            manager.dismiss()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: snackbar)
    }
}

extension View {
    /// Attaches the snackbar system to this view.
    /// - Parameter manager: The `SnackbarManager` that controls snackbar presentation.
    /// - Returns: A view that can present snackbars.
    func snackbar(manager: SnackbarManager) -> some View {
        modifier(SnackbarModifier(snackbar: manager.currentSnackbar, manager: manager))
    }
}
