import Foundation

/// Batching and retry logic, apart from the system so it can be tested.
///
/// The manager calls it from a single task, one event after the other: uploads never
/// overlap, so a view saved for retry can't be sent twice.
///
/// After a failed upload nothing is sent before a backoff (the server's Retry-After, else
/// 1 min doubling up to 30 min): batches go straight to the retry file meanwhile, so an
/// offline device or an overloaded server isn't hit again every 20 views.
actor StatsEngine {
    static let batchThreshold = 20
    static let maxBatchAgeMs: Int64 = 120_000
    static let minBackoffMs: Int64 = 60_000
    static let maxBackoffMs: Int64 = 30 * 60_000
    private static let maxDoublings = 5

    private let appId: UUID
    private let uploader: any Uploader
    private let store: RetryStore
    private let clock: @Sendable () -> Int64
    private let logger: any AssLog
    private let sessionId: UUID

    private var batch: [PageView] = []
    private var failures = 0
    private var nextAttemptAt: Int64 = 0

    init(appId: UUID, uploader: any Uploader, store: RetryStore, clock: @escaping @Sendable () -> Int64,
         log: any AssLog, sessionId: UUID = UUID()) {
        self.appId = appId
        self.uploader = uploader
        self.store = store
        self.clock = clock
        self.logger = log
        self.sessionId = sessionId
    }

    /// Sends what the previous launches left in the retry file.
    func start() async {
        await retrySaved()
    }

    /// A view of `page` at `time` (epoch ms).
    func log(_ page: UUID, at time: Int64) async {
        batch.append(PageView(page: page, sessionId: sessionId, timestamp: time))
        logger.v("log screen \(page.uuidString.lowercased())")
        let oldEnough = batch[0].timestamp + Self.maxBatchAgeMs < time
        if batch.count >= Self.batchThreshold || oldEnough {
            await send(drain())
        }
    }

    /// The app goes to background and may be suspended or killed: the batch is saved first,
    /// sent, then taken out of the file once delivered.
    func flush() async {
        let views = drain()
        guard !views.isEmpty else { return }
        store.add(views)
        if await upload(views) {
            store.remove(views)
            await retrySaved() // the server is reachable again
        }
    }

    private func send(_ views: [PageView]) async {
        if await upload(views) {
            await retrySaved() // the server is reachable again
        } else {
            store.add(views)
        }
    }

    private func retrySaved() async {
        let saved = store.read()
        guard !saved.isEmpty else { return }
        logger.v("retry \(saved.count) saved page views")
        if await upload(saved) { store.remove(saved) }
    }

    /// True when the views must not be kept; false when backing off or the server asked to retry.
    private func upload(_ views: [PageView]) async -> Bool {
        let now = clock()
        if now < nextAttemptAt { return false }
        switch await uploader.upload(ViewsPayload(app: appId, views: views, now: now)) {
        case .done:
            failures = 0
            nextAttemptAt = 0
            return true
        case let .retry(retryAfterMs):
            let backoff = retryAfterMs.map { min($0, Self.maxBackoffMs) }
                ?? min(Self.minBackoffMs << min(failures, Self.maxDoublings), Self.maxBackoffMs)
            failures += 1
            nextAttemptAt = now + backoff
            logger.v("next upload in \(backoff / 1000) s")
            return false
        }
    }

    private func drain() -> [PageView] {
        defer { batch.removeAll() }
        return batch
    }
}
