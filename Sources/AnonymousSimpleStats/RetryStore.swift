import Foundation

let maxRetryViews = 1000
let maxRetryAgeMs: Int64 = 7 * 24 * 60 * 60 * 1000

/// What the retry file keeps: views younger than `maxRetryAgeMs`, at most the
/// `maxRetryViews` most recent ones, so a device offline for long can't grow it forever.
func capRetryBatch(_ views: [PageView], now: Int64) -> [PageView] {
    Array(views.filter { now - $0.timestamp <= maxRetryAgeMs }.suffix(maxRetryViews))
}

/// Page views waiting to be sent again, kept in `file` across launches.
/// Only used from `StatsEngine`, one call at a time.
struct RetryStore: Sendable {
    let file: URL
    let clock: @Sendable () -> Int64
    let log: any AssLog

    private struct Content: Codable {
        let pageViews: [PageView]
    }

    /// In Caches, like Android's cacheDir: not backed up, not shown to the user.
    static func defaultFile() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("AnonymousSimpleStats", isDirectory: true)
            .appendingPathComponent("retry.json")
    }

    func read() -> [PageView] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        do {
            return try JSONDecoder().decode(Content.self, from: Data(contentsOf: file)).pageViews
        } catch {
            // A corrupt file is dropped rather than making every later save fail
            log.w("Corrupt retry file dropped")
            return []
        }
    }

    func add(_ views: [PageView]) {
        write(read() + views)
    }

    func remove(_ views: [PageView]) {
        let removed = Set(views)
        write(read().filter { !removed.contains($0) })
    }

    private func write(_ views: [PageView]) {
        do {
            let kept = capRetryBatch(views, now: clock())
            if kept.isEmpty {
                if FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
            } else {
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                // Atomic: written aside then renamed, so a process killed mid-write leaves the old file intact
                try JSONEncoder().encode(Content(pageViews: kept)).write(to: file, options: .atomic)
            }
        } catch {
            log.e("Could not write the retry file: \(error.localizedDescription)")
        }
    }
}
