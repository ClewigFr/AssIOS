import Foundation
import os

/// The library's logs; a protocol so the logic can be tested.
protocol AssLog: Sendable {
    var verbose: Bool { get }
    /// Only logged when `verbose`.
    func v(_ message: String)
    func w(_ message: String)
    func e(_ message: String)
}

/// Unified logging, subsystem "fr.clewig.AnonymousSimpleStats": filter on it in Xcode or Console.
struct OSAssLog: AssLog {
    let verbose: Bool
    private let logger = Logger(subsystem: "fr.clewig.AnonymousSimpleStats", category: "AnonymousSimpleStats")

    init(verbose: Bool) {
        self.verbose = verbose
    }

    func v(_ message: String) {
        if verbose { logger.info("\(message, privacy: .public)") }
    }

    func w(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func e(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

/// A value behind a lock.
final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
