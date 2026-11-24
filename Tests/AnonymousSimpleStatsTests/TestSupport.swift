import Foundation
@testable import AnonymousSimpleStats

/// Collects the library's logs instead of sending them to os_log.
final class FakeLog: AssLog, @unchecked Sendable {
    let verbose = true
    private let messages = Locked<[String]>([])
    var warnings: [String] { messages.withLock { $0 } }
    func v(_ message: String) {}
    func w(_ message: String) { messages.withLock { $0.append(message) } }
    func e(_ message: String) { messages.withLock { $0.append(message) } }
}

/// A clock the test moves by hand.
final class FakeClock: @unchecked Sendable {
    private let value: Locked<Int64>
    init(_ now: Int64 = 1_000_000_000) { value = Locked(now) }
    var now: Int64 {
        get { value.withLock { $0 } }
        set { value.withLock { $0 = newValue } }
    }
    var function: @Sendable () -> Int64 { { self.now } }
}

/// A server the test turns on and off.
final class FakeUploader: Uploader, @unchecked Sendable {
    private struct State {
        var serverUp = true
        var retryAfterMs: Int64?
        var attempts = 0
        var sent: [ViewsPayload] = []
    }
    private let state = Locked(State())

    var serverUp: Bool {
        get { state.withLock { $0.serverUp } }
        set { state.withLock { $0.serverUp = newValue } }
    }
    var retryAfterMs: Int64? {
        get { state.withLock { $0.retryAfterMs } }
        set { state.withLock { $0.retryAfterMs = newValue } }
    }
    var attempts: Int { state.withLock { $0.attempts } }
    var sent: [ViewsPayload] { state.withLock { $0.sent } }

    func upload(_ payload: ViewsPayload) async -> UploadResult {
        state.withLock {
            $0.attempts += 1
            guard $0.serverUp else { return .retry(retryAfterMs: $0.retryAfterMs) }
            $0.sent.append(payload)
            return .done
        }
    }
}

/// A new empty directory, removed with its owner.
final class TemporaryDirectory {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("AnonymousSimpleStatsTests-\(UUID().uuidString)", isDirectory: true)

    init() {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    var contents: [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    }
}
