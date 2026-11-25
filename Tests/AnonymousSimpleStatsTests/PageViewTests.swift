import Foundation
import Testing
@testable import AnonymousSimpleStats

struct PageViewTests {
    let view = PageView(page: UUID(), sessionId: UUID(), timestamp: 1_000_000)

    @Test func localFormatKeepsTheAbsoluteTimestamp() throws {
        let decoded = try JSONDecoder().decode(PageView.self, from: JSONEncoder().encode(view))
        #expect(decoded == view)
    }

    @Test func wireFormatSendsTheElapsedTime() {
        let payload = ViewsPayload(app: UUID(), views: [view], now: 1_000_500)
        #expect(payload.pageViews[0].timestamp == 500)
    }

    @Test func clockMovedBackwardsSendsZero() {
        let payload = ViewsPayload(app: UUID(), views: [view], now: 999_000)
        #expect(payload.pageViews[0].timestamp == 0)
    }

    @Test func parsesTheAppId() {
        let id = UUID()
        #expect(parseAppId(" \(id.uuidString.lowercased()) ") == id)
        #expect(parseAppId("not-a-uuid") == nil)
        #expect(parseAppId("") == nil)
    }

    @Test func payloadIsWhatTheBackendExpects() throws {
        let app = UUID()
        let data = try JSONEncoder().encode(ViewsPayload(app: app, views: [view], now: 1_000_250))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["app"] as? String == app.uuidString.lowercased())
        let views = try #require(json["pageViews"] as? [[String: Any]])
        #expect(views.count == 1)
        #expect(views[0]["page"] as? String == view.page.uuidString.lowercased())
        #expect(views[0]["sessionId"] as? String == view.sessionId.uuidString.lowercased())
        // A JSON number, not a string
        #expect(views[0]["timestamp"] as? NSNumber == 250)
        #expect(Set(views[0].keys) == ["page", "sessionId", "timestamp"])
    }
}
