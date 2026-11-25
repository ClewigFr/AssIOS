#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Logs a view of `pageId` each time this screen becomes visible: when it appears while the
    /// app is in the foreground, and each time the app comes back to the foreground with this
    /// screen shown. The SwiftUI equivalent of Android's `TrackScreen`.
    ///
    /// ```swift
    /// var body: some View {
    ///     CartContent()
    ///         .trackScreen(stats, AssPages.panier)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - stats: the instance from `AnonymousSimpleStatsManager.getInstance`
    ///   - pageId: the page UUID from the dashboard
    func trackScreen(_ stats: AnonymousSimpleStatsManager, _ pageId: String) -> some View {
        modifier(TrackScreenModifier(pageId: pageId, logScreen: { stats.logScreen($0) }))
    }
}

struct TrackScreenModifier: ViewModifier {
    let pageId: String
    let logScreen: @Sendable (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var tracker = ScreenTracker()

    func body(content: Content) -> some View {
        content
            .onAppear {
                if tracker.appeared(active: scenePhase == .active) { logScreen(pageId) }
            }
            .onDisappear { tracker.disappeared() }
            .onNewValue(of: scenePhase) { phase in
                if tracker.phaseChanged(to: ScreenPhase(phase)) { logScreen(pageId) }
            }
            .onNewValue(of: pageId) { newPage in
                // The same view showing another page logs it at once
                if tracker.pageChanged(active: scenePhase == .active) { logScreen(newPage) }
            }
    }
}

private extension View {
    /// onChange without the iOS 17 deprecation warning, with the API each version has.
    @ViewBuilder
    func onNewValue<Value: Equatable>(of value: Value, _ action: @escaping (Value) -> Void) -> some View {
        #if os(visionOS)
        onChange(of: value) { _, newValue in action(newValue) }
        #else
        if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
        #endif
    }
}

extension ScreenPhase {
    init(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .active
        case .background: self = .background
        default: self = .inactive
        }
    }
}
#endif

enum ScreenPhase {
    case active, inactive, background
}

/// When `trackScreen` logs, apart from SwiftUI for the tests: once on appearing in the
/// foreground (or at the next activation if the scene isn't active yet), then each time the app
/// comes back from the background. An inactive moment (Control Center, a system alert) isn't a
/// new view.
struct ScreenTracker {
    private var visible = false
    private var pending = false

    mutating func appeared(active: Bool) -> Bool {
        visible = true
        return activate(active)
    }

    mutating func disappeared() {
        visible = false
        pending = false
    }

    mutating func pageChanged(active: Bool) -> Bool {
        guard visible else { return false }
        return activate(active)
    }

    mutating func phaseChanged(to phase: ScreenPhase) -> Bool {
        guard visible else { return false }
        switch phase {
        case .background:
            pending = true
            return false
        case .inactive:
            return false
        case .active:
            defer { pending = false }
            return pending
        }
    }

    private mutating func activate(_ active: Bool) -> Bool {
        pending = !active
        return active
    }
}
