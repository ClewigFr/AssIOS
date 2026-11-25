import Foundation

/// Configuration of the stats manager.
public struct AssConfig: Sendable, Equatable {
    /// Base URL of the AssBackend server, e.g. "https://stats.example.com".
    public let endpoint: String
    /// UUID of your application, shown in the dashboard when you create it. Page views are
    /// only accepted for pages of this application. A malformed one disables the library.
    public let appId: String
    /// Log every event (debug builds only).
    public let verbose: Bool

    public init(endpoint: String, appId: String, verbose: Bool = false) {
        self.endpoint = endpoint
        self.appId = appId
        self.verbose = verbose
    }
}

/// Entry point of the library: get it with `getInstance(_:)`, then call `logScreen(_:)` on every screen.
/// Never crashes the host app; a bad configuration only disables it (see the logs).
public final class AnonymousSimpleStatsManager: Sendable {

    enum Event: Sendable {
        case log(UUID, at: Int64)
        case flush(done: @Sendable () -> Void)
    }

    let config: AssConfig
    private let logger: any AssLog
    private let clock: @Sendable () -> Int64
    /// Nil when the configuration is invalid: the library is then disabled.
    private let events: AsyncStream<Event>.Continuation?

    private static let instance = Locked<AnonymousSimpleStatsManager?>(nil)

    /// The single instance, created on the first call; later calls return it and ignore
    /// their argument (with a warning when `config` differs).
    public static func getInstance(_ config: AssConfig) -> AnonymousSimpleStatsManager {
        let (manager, created) = instance.withLock { current -> (AnonymousSimpleStatsManager, Bool) in
            if let current { return (current, false) }
            let manager = AnonymousSimpleStatsManager(config: config)
            current = manager
            return (manager, true)
        }
        if !created, manager.config != config {
            manager.logger.w("getInstance called again with a different AssConfig: it is ignored, the first one is kept")
        }
        return manager
    }

    init(config: AssConfig, clock: @escaping @Sendable () -> Int64 = systemClock) {
        self.config = config
        self.clock = clock
        let logger = OSAssLog(verbose: config.verbose)
        self.logger = logger

        guard let appId = parseAppId(config.appId) else {
            logger.e("Invalid appId \"\(config.appId)\": it must be the application UUID from the dashboard. Stats are disabled.")
            events = nil
            return
        }
        guard let url = viewsURL(config.endpoint) else {
            logger.e("Invalid endpoint \"\(config.endpoint)\": it must be an http(s) URL. Stats are disabled.")
            events = nil
            return
        }
        if url.scheme?.lowercased() == "http" {
            logger.w("Endpoint \"\(config.endpoint)\" is cleartext http: App Transport Security blocks it unless the app's Info.plist allows it")
        }

        let engine = StatsEngine(
            appId: appId,
            uploader: HttpUploader(url: url, log: logger),
            store: RetryStore(file: RetryStore.defaultFile(), clock: clock, log: logger),
            clock: clock,
            log: logger
        )
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        events = continuation

        // One consumer, so events are handled one at a time and in order: uploads never overlap
        Task.detached(priority: .utility) {
            removeLegacyBackup(log: logger)
            await engine.start()
            for await event in stream {
                switch event {
                case let .log(page, time):
                    await engine.log(page, at: time)
                case let .flush(done):
                    await engine.flush()
                    done()
                }
            }
        }
        BackgroundWatcher.observe { [continuation, logger] in
            logger.v("onBackground upload")
            Self.flushInBackground(continuation)
        }
        logger.v("setup")
    }

    /// Log a view of a screen.
    ///
    /// - Parameter pageId: the page UUID from the dashboard; anything else is ignored with a warning
    public func logScreen(_ pageId: String) {
        guard let events else { return }
        guard let page = UUID(uuidString: pageId) else {
            logger.w("Ignored page view: \"\(pageId)\" is not a UUID")
            return
        }
        events.yield(.log(page, at: clock()))
    }

    /// The app leaves the screen and may be suspended: the batch is saved then sent, and the
    /// process is kept alive for it (at most 25 s, or less if the system says so).
    private static func flushInBackground(_ events: AsyncStream<Event>.Continuation) {
        let done = DispatchSemaphore(value: 0)
        events.yield(.flush(done: { done.signal() }))
        #if !os(macOS) // a Mac app isn't suspended when it leaves the foreground
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Sending anonymous page views") { expired in
            if expired {
                done.signal()
            } else {
                _ = done.wait(timeout: .now() + 25)
            }
        }
        #endif
    }
}

let systemClock: @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }

/// Versions up to 0.2.0 kept failed views in the Documents directory (visible to the user,
/// backed up to iCloud), in a format without the application: removed.
private func removeLegacyBackup(log: any AssLog) {
    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let legacy = documents.appendingPathComponent(".anonymousSimpleStatsBackup.data")
    if (try? FileManager.default.removeItem(at: legacy)) != nil {
        log.v("removed the retry file of version 0.2.0")
    }
}
