# AssIOS

Swift package `AnonymousSimpleStats`: anonymous page-view stats for iOS, tvOS, visionOS and macOS apps. No dependencies.
README.md is for users of the library, AI_INTEGRATION.md for assistants integrating it into an app; this file is for working on the library itself.

## Commands

- `swift test`: unit tests (Swift Testing, not XCTest).
- What the CI runs (`.github/workflows/ci.yml`), all of it must pass:
  ```sh
  swift test
  xcodebuild -scheme AnonymousSimpleStats -destination 'generic/platform=iOS Simulator' -quiet build
  xcodebuild -scheme AnonymousSimpleStats -destination 'generic/platform=tvOS Simulator' -quiet build
  xcodebuild -project Example/AssExample.xcodeproj -scheme AssExample -destination 'generic/platform=iOS Simulator' -quiet build
  ```
- Keep the build free of warnings (Swift 6 language mode, strict concurrency).

## Layout (`Sources/AnonymousSimpleStats/`)

- `AnonymousSimpleStatsManager.swift`: public API (`AssConfig`, `getInstance(_:)`, `logScreen(_:)`); runs the engine on a single task.
- `StatsEngine.swift`: batching, flush, backoff, retry. No system calls, so it is fully testable.
- `Uploader.swift`: `POST /views` over an ephemeral `URLSession`, status handling, `Retry-After`, gzip negotiation.
- `RetryStore.swift`: retry file in Caches (1000 views max, 7 days).
- `PageView.swift`: model and wire format. `Gzip.swift`: RFC 1952 on top of the Compression framework.
- `BackgroundWatcher.swift`: app-to-background notifications (raw names, no UIKit/AppKit import).
- `TrackScreen.swift`: SwiftUI `.trackScreen(stats, pageId)`.
- `AssLog.swift`: unified logging, subsystem `fr.clewig.AnonymousSimpleStats`.
- `PrivacyInfo.xcprivacy`: privacy manifest. Keep it, `confidentiality-policy.md` and the README in sync with what is actually sent.

Logic depends on protocols (`Uploader`, `AssLog`, clock) so tests use fakes (`Tests/.../TestSupport.swift`); keep new logic out of the system-facing types.

## Parity with Android

Behavior must stay identical to the Android library (AssAndroid, `../assKotlin` locally) for the same version number: batch of 20 views or 2 minutes, flush on background, retry file limits, backoff (Retry-After, else 1 min doubling to 30 min), status handling. A change of behavior here means the same change there, and a CHANGELOG entry in both.

## Backend contract (`../assBackend`, `src/controller/PageViewsController.kt`)

- Body: `{"app": "<uuid>", "pageViews": [{"page", "sessionId", "timestamp"}]}`. `app` is required (the backend answers 400 without it).
- UUIDs are sent lowercase.
- `timestamp` on the wire is the **time elapsed since the view, in ms** (never negative), not an epoch date. `PageView.timestamp` in memory is an epoch time; the conversion happens in `ViewsPayload`.
- At most 1000 views per request and 1 MB of JSON: the retry file is sent as its own request and is capped at 1000 views. Never send more, a 400 makes the client drop the batch for good.
- 200 / 206 / 400 = done, never resent. Anything else (415, 429, 503, network errors) = kept and retried.
- Gzip the body only after the server has answered with `Accept-Encoding: gzip`, and stop after a 415.

## Privacy

No identifier other than the random per-session UUID. No cookies, no cache, no device or app info (neutral User-Agent). Don't add fields to the payload without updating the privacy manifest and `confidentiality-policy.md`.

## Releases

Tags are bare versions (`0.5.0`) and follow the Android version numbers. Update CHANGELOG.md, with migration notes for breaking changes.
