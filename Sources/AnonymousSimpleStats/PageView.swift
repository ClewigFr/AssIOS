import Foundation

/// One view of a page. `timestamp` is in epoch milliseconds.
struct PageView: Codable, Hashable, Sendable {
    let page: UUID
    let sessionId: UUID
    let timestamp: Int64
}

/// Wire format of one view: "timestamp" is the time elapsed since the view, in milliseconds.
struct WireView: Encodable, Equatable, Sendable {
    let page: String
    let sessionId: String
    let timestamp: Int64
}

/// Body of POST /views: {"app": "<uuid>", "pageViews": [...]}.
struct ViewsPayload: Encodable, Equatable, Sendable {
    let app: String
    let pageViews: [WireView]

    /// Elapsed times are computed at `now`, never negative (a clock moved backwards must not send a negative value).
    init(app: UUID, views: [PageView], now: Int64) {
        self.app = app.uuidString.lowercased()
        self.pageViews = views.map {
            WireView(page: $0.page.uuidString.lowercased(),
                     sessionId: $0.sessionId.uuidString.lowercased(),
                     timestamp: max(now - $0.timestamp, 0))
        }
    }
}

/// The application UUID from `appId`, or nil when it's malformed.
func parseAppId(_ appId: String) -> UUID? {
    UUID(uuidString: appId.trimmingCharacters(in: .whitespacesAndNewlines))
}
