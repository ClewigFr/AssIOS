import Foundation
import Testing
@testable import AnonymousSimpleStats

struct UploaderTests {
    let log = FakeLog()

    @Test func acceptedAndRejectedBatchesAreNotRetried() {
        #expect(isHandled(200, log: log))
        #expect(isHandled(206, log: log))
        #expect(isHandled(400, log: log))
    }

    @Test(arguments: [401, 404, 415, 429, 500, 503])
    func otherCodesAreRetried(code: Int) {
        #expect(!isHandled(code, log: log))
    }

    @Test func buildsTheViewsURL() {
        #expect(viewsURL(" https://stats.example.com/ ")?.absoluteString == "https://stats.example.com/views")
        #expect(viewsURL("http://localhost:8099")?.absoluteString == "http://localhost:8099/views")
        #expect(viewsURL("not a url") == nil)
        #expect(viewsURL("file:///etc/passwd") == nil)
        #expect(viewsURL("") == nil)
    }

    @Test func parsesRetryAfterSeconds() {
        #expect(parseRetryAfter(" 30 ") == 30_000)
        #expect(parseRetryAfter("Wed, 21 Oct 2015 07:28:00 GMT") == nil)
        #expect(parseRetryAfter("-1") == nil)
        #expect(parseRetryAfter(nil) == nil)
    }

    @Test func readsAcceptEncoding() {
        #expect(acceptsGzip("gzip"))
        #expect(acceptsGzip("br, GZIP;q=0.5"))
        #expect(!acceptsGzip("identity"))
        #expect(!acceptsGzip(nil))
    }
}
