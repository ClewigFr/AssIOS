import Foundation
import Testing
@testable import AnonymousSimpleStats

final class StatsEngineTests {
    let folder = TemporaryDirectory()
    let clock = FakeClock()
    let server = FakeUploader()
    let app = UUID()
    lazy var store = RetryStore(file: folder.url.appendingPathComponent("retry.json"), clock: clock.function, log: FakeLog())
    lazy var engine = StatsEngine(appId: app, uploader: server, store: store, clock: clock.function, log: FakeLog())

    let threshold = StatsEngine.batchThreshold

    func log(_ count: Int = 1) async {
        for _ in 0..<count { await engine.log(UUID(), at: clock.now) }
    }

    var sentCounts: [Int] { server.sent.map(\.pageViews.count) }

    @Test func sendsOnceTheThresholdIsReached() async {
        await log(threshold - 1)
        #expect(server.sent.isEmpty)
        await log()
        #expect(sentCounts == [threshold])
        #expect(server.sent[0].app == app.uuidString.lowercased())
    }

    @Test func sendsWhenTheOldestViewIsOldEnough() async {
        await log()
        clock.now += StatsEngine.maxBatchAgeMs + 1
        await log()
        #expect(sentCounts == [2])
    }

    @Test func failedBatchIsSavedThenResentWhenTheServerIsBack() async {
        server.serverUp = false
        await log(threshold)
        #expect(store.read().count == threshold)

        server.serverUp = true
        clock.now += StatsEngine.minBackoffMs
        await log(threshold)
        #expect(sentCounts == [threshold, threshold])
        #expect(store.read().isEmpty)
    }

    @Test func flushSavesFirstAndForgetsOnceDelivered() async {
        await log()
        await engine.flush()
        #expect(sentCounts == [1])
        #expect(store.read().isEmpty)
    }

    @Test func flushKeepsTheBatchWhenTheServerIsDown() async {
        server.serverUp = false
        await log()
        await engine.flush()
        #expect(store.read().count == 1)
    }

    @Test func emptyFlushSendsNothing() async {
        await engine.flush()
        #expect(server.attempts == 0)
    }

    @Test func deliveredFlushAlsoResendsWhatWasSaved() async {
        server.serverUp = false
        await log()
        await engine.flush()
        #expect(store.read().count == 1)

        server.serverUp = true
        clock.now += StatsEngine.minBackoffMs
        await log()
        await engine.flush()
        #expect(sentCounts == [1, 1])
        #expect(store.read().isEmpty)
    }

    @Test func startResendsWhatThePreviousRunSaved() async {
        store.add([PageView(page: UUID(), sessionId: UUID(), timestamp: clock.now - 5_000)])
        clock.now += 1_000
        await engine.start()
        #expect(sentCounts == [1])
        #expect(server.sent.first?.pageViews.first?.timestamp == 6_000)
        #expect(store.read().isEmpty)
    }

    @Test func eachViewIsSentOnlyOnce() async {
        await engine.start()
        await log(threshold * 2 + 3)
        await engine.flush()
        let pages = server.sent.flatMap { $0.pageViews.map(\.page) }
        #expect(pages.count == threshold * 2 + 3)
        #expect(Set(pages).count == pages.count)
    }

    @Test func viewsOfOneLaunchShareASession() async {
        await log(threshold)
        #expect(Set(server.sent[0].pageViews.map(\.sessionId)).count == 1)
    }

    @Test func backsOffAfterAFailureThenDoublesTheWait() async {
        server.serverUp = false
        await log(threshold * 3)
        #expect(server.attempts == 1) // the next two batches went straight to the file
        #expect(store.read().count == threshold * 3)

        clock.now += StatsEngine.minBackoffMs
        await log(threshold)
        #expect(server.attempts == 2)
        clock.now += StatsEngine.minBackoffMs // the wait is now 2 min
        await log(threshold)
        #expect(server.attempts == 2)
    }

    @Test func followsRetryAfter() async {
        server.serverUp = false
        server.retryAfterMs = 5_000
        await log(threshold)
        server.serverUp = true
        clock.now += 5_000
        await log(threshold)
        #expect(server.attempts == 3) // failed batch, new batch, then the saved one
        #expect(sentCounts == [threshold, threshold])
        #expect(store.read().isEmpty)
    }

    @Test func flushDuringBackoffOnlySaves() async {
        server.serverUp = false
        await log(threshold + 1)
        await engine.flush()
        #expect(server.attempts == 1)
        #expect(store.read().count == threshold + 1)
    }
}
