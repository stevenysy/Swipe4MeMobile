import Foundation
import SwiftUI

/// The configuration for a single snackbar message.
struct Snackbar: Equatable {
    var title: String
    var style: SnackbarStyle
    var duration: TimeInterval = 3  // Default duration
}

/// Defines the visual style of the snackbar.
enum SnackbarStyle {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info: .blue
        case .success: .green
        case .warning: .yellow
        case .error: .red
        }
    }

    var iconSystemName: String {
        switch self {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }
}
