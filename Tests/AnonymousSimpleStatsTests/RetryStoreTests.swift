import Foundation
import Testing
@testable import AnonymousSimpleStats

final class RetryStoreTests {
    let folder = TemporaryDirectory()
    let clock = FakeClock()
    let session = UUID()

    func store(_ log: FakeLog = FakeLog()) -> RetryStore {
        RetryStore(file: folder.url.appendingPathComponent("retry.json"), clock: clock.function, log: log)
    }

    func view(age: Int64 = 0) -> PageView {
        PageView(page: UUID(), sessionId: session, timestamp: clock.now - age)
    }

    @Test func addAndRemove() {
        let store = store()
        let a = view(), b = view()
        store.add([a])
        store.add([b])
        #expect(store.read() == [a, b])
        store.remove([a, b])
        #expect(!FileManager.default.fileExists(atPath: store.file.path))
    }

    @Test func writeLeavesNoTemporaryFile() {
        let store = store()
        store.add([view()])
        store.add([view()])
        #expect(store.read().count == 2)
        #expect(folder.contents == ["retry.json"])
    }

    @Test func corruptFileIsReplaced() throws {
        let log = FakeLog()
        let store = store(log)
        try Data("{oops".utf8).write(to: store.file)
        let a = view()
        store.add([a])
        #expect(store.read() == [a])
        #expect(log.warnings == ["Corrupt retry file dropped"])
    }

    @Test func createsItsDirectory() {
        let store = RetryStore(file: folder.url.appendingPathComponent("sub/retry.json"), clock: clock.function, log: FakeLog())
        let a = view()
        store.add([a])
        #expect(store.read() == [a])
    }

    @Test func capDropsOldViewsAndKeepsTheMostRecent() {
        let old = view(age: maxRetryAgeMs + 1)
        let recent = (1...(maxRetryViews + 5)).reversed().map { view(age: Int64($0)) }
        #expect(capRetryBatch([old] + recent, now: clock.now) == Array(recent.suffix(maxRetryViews)))
    }
}
