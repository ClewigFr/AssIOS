# Changelog

Version numbers follow the Android library ([AssAndroid](https://github.com/ClewigFr/AssAndroid)): the same version has the same behavior on both platforms.

## 0.5.0

Rewritten to match the Android library 0.5.0. Breaking changes, see **Migrating from 0.2.0**.

### Added
- Distributed as a Swift package (`https://github.com/ClewigFr/AssIOS`, product `AnonymousSimpleStats`).
- `getInstance(AssConfig(endpoint:appId:verbose:))`: the backend URL and the application UUID
  from the dashboard are configured by the app. A malformed `appId` or endpoint disables the library
  with an error log.
- `trackScreen(stats, pageId)` for SwiftUI: logs a view when the screen is shown and each time the
  app comes back to the foreground with it.
- Retry after failures: failed batches are kept in Caches (at most 1000 views, 7 days), resent after
  the next successful upload or at the next launch. After a failure, nothing is sent before the
  server's `Retry-After`, otherwise 1 minute doubling up to 30 minutes.
- Bodies are gzipped once the server answers with `Accept-Encoding: gzip`.
- A privacy manifest (`PrivacyInfo.xcprivacy`).
- [AI_INTEGRATION.md](AI_INTEGRATION.md), a guide for AI coding assistants.
- Tests (Swift Testing), CI, and an example app in `Example/`.

### Changed
- Every request carries the application UUID (`"app"`): the backend refuses views without it.
- `timestamp` is a number of milliseconds (it was a string, rounded down to whole seconds).
- A batch is sent at 20 queued views or when the oldest is 2 minutes old (was 5 views or 1 minute),
  and when the app goes to the background (was when it resigned active, e.g. on opening Control
  Center). That batch is saved to disk before it is sent, and the app is kept running for the upload.
- Requests use an ephemeral session: no cookies, no cache, a neutral User-Agent. Timeouts are 15 s.
- Logs go to the unified logging system (subsystem `fr.clewig.AnonymousSimpleStats`) instead of `print`.
- iOS 15 minimum (was iOS 9). Also tvOS 15, visionOS 1, macOS 12.

### Removed
- The CocoaPods pod and `AnonymousSimpleStats.podspec`.
- `AnonymousSimpleStatsManager.shared`, `setup(verbose:)` and the `AnonymousManager` alias.
- The hard-coded endpoint (`gentle-inlet-02091.herokuapp.com`).
- Skipping a view logged twice within half a second: each call is a view, as on Android.

### Fixed
- Views sent while another upload was running were neither sent nor saved.
- A batch could be sent again after being saved for retry, and saved views were lost if the app was
  killed between restoring and resending them.
- The retry file was kept in Documents, visible to the user and backed up to iCloud. It is in Caches
  now; the old file is deleted.

### Migrating from 0.2.0

1. Remove `pod 'AnonymousSimpleStats'` from the Podfile and run `pod install`, then add the package
   (see the README).
2. Replace the setup:
   ```swift
   // Before
   AnonymousSimpleStatsManager.shared.setup(verbose: true)
   AnonymousSimpleStatsManager.shared.logScreen(pageId: "…")

   // After
   let stats = AnonymousSimpleStatsManager.getInstance(
       AssConfig(endpoint: "https://ass-api.clewig.fr", appId: "<application UUID>", verbose: true)
   )
   stats.logScreen("…")
   ```
3. Pages created before applications existed were moved by the backend into an "Application par
   défaut": use its UUID as `appId`, the page UUIDs don't change.

## 0.2.0 and earlier

CocoaPods releases, see the git tags.
