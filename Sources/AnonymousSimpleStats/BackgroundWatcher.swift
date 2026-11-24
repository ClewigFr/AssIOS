import Foundation

/// Calls a function when the app leaves the screen. Uses the notifications' raw names so the
/// library doesn't need UIKit or AppKit.
enum BackgroundWatcher {
    #if os(macOS)
    static let notification = Notification.Name("NSApplicationDidResignActiveNotification")
    #else
    static let notification = Notification.Name("UIApplicationDidEnterBackgroundNotification")
    #endif

    /// The observer stays registered for the life of the process, like the manager.
    static func observe(_ onBackground: @escaping @Sendable () -> Void) {
        _ = NotificationCenter.default.addObserver(forName: notification, object: nil, queue: nil) { _ in
            onBackground()
        }
    }
}
