import Foundation

/// What became of one POST /views.
enum UploadResult: Equatable, Sendable {
    /// The server handled the batch (accepted or rejected for good): never resend it.
    case done
    /// Send it again later, not before `retryAfterMs` when the server said so (Retry-After).
    case retry(retryAfterMs: Int64? = nil)
}

/// Sends one POST /views body.
protocol Uploader: Sendable {
    func upload(_ payload: ViewsPayload) async -> UploadResult
}

let configHint = "check that appId and the page UUIDs passed to logScreen come from the same application in the dashboard"

/// 200 and 206 mean accepted, 400 means rejected (retrying wouldn't help), anything else
/// (incl. 415/429/503) means retry. True if the batch must not be retried.
func isHandled(_ statusCode: Int, log: any AssLog) -> Bool {
    switch statusCode {
    case 200:
        log.v("OK")
        return true
    case 206:
        log.w("Some page views were rejected: \(configHint)")
        return true
    case 400:
        log.w("Page views rejected by the server (400): \(configHint)")
        return true
    default:
        log.w("Server answered \(statusCode), page views kept for retry")
        return false
    }
}

/// Retry-After in seconds as milliseconds; the HTTP-date form and garbage give nil.
func parseRetryAfter(_ header: String?) -> Int64? {
    guard let header, let seconds = Int64(header.trimmingCharacters(in: .whitespaces)), seconds >= 0 else { return nil }
    return seconds * 1000
}

/// Whether a response's Accept-Encoding (RFC 7694) says request bodies may be gzipped.
func acceptsGzip(_ header: String?) -> Bool {
    guard let header else { return false }
    return header.split(separator: ",").contains {
        $0.split(separator: ";", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces).lowercased() == "gzip"
    }
}

/// The http(s) URL of POST /views under `endpoint`, or nil when it is malformed.
func viewsURL(_ endpoint: String) -> URL? {
    var base = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    while base.hasSuffix("/") { base.removeLast() }
    guard let url = URL(string: base + "/views"),
          let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
          let host = url.host, !host.isEmpty
    else { return nil }
    return url
}

/// POST over an ephemeral URLSession: no cookies, no cache, a neutral User-Agent. Bodies are
/// only gzipped once the server has advertised it with Accept-Encoding, so an older backend
/// never gets a body it can't read.
actor HttpUploader: Uploader {
    private static let timeout: TimeInterval = 15

    private let url: URL
    private let log: any AssLog
    private let session: URLSession
    private var gzip = false

    init(url: URL, log: any AssLog) {
        self.url = url
        self.log = log
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        // The default one names the app, its version and the OS version
        configuration.httpAdditionalHeaders = ["User-Agent": "AnonymousSimpleStats"]
        session = URLSession(configuration: configuration)
    }

    func upload(_ payload: ViewsPayload) async -> UploadResult {
        let json: Data
        do {
            json = try JSONEncoder().encode(payload)
        } catch {
            log.e("Could not encode the page views, dropped: \(error.localizedDescription)")
            return .done
        }
        if log.verbose { log.v(String(decoding: json, as: UTF8.self)) }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if gzip, let compressed = gzipped(json) {
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            request.httpBody = compressed
            log.v("POST \(url.path) (gzip)")
        } else {
            request.httpBody = json
            log.v("POST \(url.path)")
        }

        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                log.w("Upload failed (no HTTP response), page views kept for retry")
                return .retry()
            }
            gzip = http.statusCode != 415 && acceptsGzip(http.value(forHTTPHeaderField: "Accept-Encoding"))
            if log.verbose, !body.isEmpty { log.v(String(decoding: body, as: UTF8.self)) }
            if isHandled(http.statusCode, log: log) { return .done }
            return .retry(retryAfterMs: parseRetryAfter(http.value(forHTTPHeaderField: "Retry-After")))
        } catch {
            // Offline, timeout, DNS, ATS…: the batch is kept and retried later
            log.w("Upload failed (\(error.localizedDescription)), page views kept for retry")
            return .retry()
        }
    }}
