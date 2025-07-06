import Foundation
import Observation
import SwiftUI

/// An observable object that manages the presentation of snackbars.
///
/// This manager should be accessed via the shared instance.
@Observable
@MainActor
class SnackbarManager {
    static let shared = SnackbarManager()
    
    private(set) var currentSnackbar: Snackbar?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Shows a snackbar with the given configuration.
    ///
    /// If a snackbar is already being shown, it will be replaced by the new one.
    /// - Parameter snackbar: The `Snackbar` to present.
    func show(snackbar: Snackbar) {
        // If a snackbar is already visible, cancel its dismiss timer
        dismissTask?.cancel()

        // Set the new snackbar
        currentSnackbar = snackbar

        // Schedule the dismissal of the new snackbar
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(snackbar.duration))
            // Check if the task was cancelled before dismissing
            if !Task.isCancelled {
                dismiss()
            }
        }
    }

    /// Shows a snackbar with a simple title and style.
    func show(title: String, style: SnackbarStyle = .info) {
        show(snackbar: Snackbar(title: title, style: style))
    }

    /// Hides the currently presented snackbar.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentSnackbar = nil
    }
}
