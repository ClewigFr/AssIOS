# AssIOS — Anonymous Simple Stats

[![CI](https://github.com/ClewigFr/AssIOS/actions/workflows/ci.yml/badge.svg)](https://github.com/ClewigFr/AssIOS/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A lightweight, anonymous Swift package for tracking screen views on iOS, iPadOS, tvOS and visionOS.
The iOS counterpart of [AssAndroid](https://github.com/ClewigFr/AssAndroid): same backend, same behavior, same version numbers.

Simple Stats collects no user identifiers, no device IDs and no personal data. Each screen view is sent as:

| Field       | Meaning                                                      |
|-------------|--------------------------------------------------------------|
| `app`       | Your application's UUID, created in the dashboard            |
| `page`      | The UUID of a page you added to that application in the dashboard |
| `sessionId` | A random UUID generated on every app launch, never persisted |
| `timestamp` | How many milliseconds ago the view happened, at send time    |

## Installation

Swift Package Manager, iOS 15+, tvOS 15+, visionOS 1+ (macOS 12+ also builds). No dependency.

In Xcode: **File → Add Package Dependencies…**, enter `https://github.com/ClewigFr/AssIOS`, and add the `AnonymousSimpleStats` library to your app target.

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ClewigFr/AssIOS", from: "0.5.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "AnonymousSimpleStats", package: "AssIOS")
    ])
]
```

Versions up to 0.2.0 were a CocoaPods pod. The pod isn't published anymore: see the [CHANGELOG](CHANGELOG.md) to migrate.

## Integration

```swift
import AnonymousSimpleStats

// Usually in your App's init, or application(_:didFinishLaunchingWithOptions:)
let stats = AnonymousSimpleStatsManager.getInstance(
    AssConfig(
        endpoint: "https://your-ass-backend.example.com",
        appId: "c4740a37-572d-488f-9fc4-40cf1575739b", // from the dashboard: "Mes applications"
        verbose: true // debug builds only
    )
)

// Whenever a screen is shown, with the UUID of that page in the dashboard
stats.logScreen("ed1129dd-c159-4bf8-9851-3016b9d6ee3a")
```

Setup: in the dashboard, create an application (you get its UUID), then add one page per screen you want to track (each gets a UUID).

### SwiftUI

```swift
struct CartScreen: View {
    var body: some View {
        CartContent()
            .trackScreen(stats, AssPages.panier) // logs when shown and each time the app comes back to the foreground
    }
}
```

`trackScreen` logs when the view appears, again when it appears again (back from a pushed screen), and each time the app comes back from the background with it shown. A brief inactive moment (Control Center, a system alert) isn't a new view.

### UIKit

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    stats.logScreen(AssPages.panier)
}
```

### Many screens at once, or with an AI assistant

The dashboard can import page names from a CSV (**Importer un CSV**) and export them with their UUIDs (**Exporter en CSV**: `name,id,app_id`).

[AI_INTEGRATION.md](AI_INTEGRATION.md) is written for AI coding assistants. It has two phases:
1. the assistant lists the app's screens in a CSV, which you import in the dashboard;
2. from the exported CSV, the assistant adds the package: the dependency, a Swift enum with the ids, the initialization, and the calls for SwiftUI and UIKit.

Ask: *"Read AI_INTEGRATION.md from the Anonymous Simple Stats package and follow phase 1"*, then, with the export, *"follow phase 2"*.

`logScreen` ignores (and logs) ids that aren't valid UUIDs instead of crashing. A malformed `appId` or endpoint logs an error and disables the library, rather than sending views the server would reject.

## How it works

- Page views are kept in memory and sent in a batch when:
  - 20 views are queued, or
  - the oldest queued view is more than 2 minutes old, or
  - the app goes to the background. That batch is written to disk before it is sent, and the app is kept running for the upload (a few seconds, as the system allows).
- Batches are sent by `POST` to `/views` as `{"app": "<uuid>", "pageViews": [...]}`, one at a time.
- If sending fails, the batch is written to the Caches directory (at most 1000 views, 7 days) and sent again after the next successful upload or on the next launch.
- After a failure, nothing is sent for a while: the server's `Retry-After`, otherwise 1 minute doubling up to 30 minutes. Batches go straight to the retry file meanwhile.
- Bodies are gzipped once the server has answered with `Accept-Encoding: gzip`, so an older backend never receives a body it can't read.
- Requests go through an ephemeral `URLSession`: no cookies, no cache, and a neutral `User-Agent` instead of the default one, which names the app and the OS version.
- Logs go to the unified logging system, subsystem `fr.clewig.AnonymousSimpleStats`. With `verbose`, every view and request is logged.
- The package ships a privacy manifest (`PrivacyInfo.xcprivacy`): product interaction, for analytics, not linked to the user, no tracking. Declare the same in your app's App Store privacy details.

### Server responses

| Code  | Meaning                                       | What the client does |
|-------|-----------------------------------------------|----------------------|
| `200` | All views accepted                            | Clears the batch     |
| `206` | Accepted, but some unknown page IDs were dropped | Clears the batch  |
| `400` | Nothing accepted                              | Clears the batch     |
| `415` | Unsupported `Content-Encoding`               | Saves the batch, retries uncompressed |
| `429` / `503` | Rate limited / server busy           | Saves the batch, waits for `Retry-After` |
| other | Server error                                  | Saves the batch to retry later |

### Limits of the hosted service

Each account on the server has, by default:
- **5 applications** and **30 pages per application**. The dashboard refuses to create more, and a CSV import that would go over is refused as a whole.
- **100,000 page views per month** (calendar month, UTC, all the account's applications together). This is a soft limit: views keep being recorded, and the dashboard shows an alert. The library is never refused views because of it.

A self-hosted backend sets its own values (`MAX_APPS`, `MAX_PAGES_PER_APP`, `MAX_MONTHLY_VIEWS`, `0` for no limit): see the backend's README.

A plain `http://` endpoint is blocked by App Transport Security unless the app's `Info.plist` allows it (the library logs a warning).

## Example app

`Example/AssExample.xcodeproj` is a SwiftUI test bench using the package from this folder: one button per page, a button logging 25 views at once, and `trackScreen` on the first page. Its build settings `ASS_ENDPOINT` (default `http://localhost:8099`, the backend in dev: the simulator shares the Mac's network), `ASS_APP_ID` and `ASS_PAGES` (comma-separated page UUIDs) configure it:

```bash
xcodebuild -project Example/AssExample.xcodeproj -scheme AssExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  ASS_APP_ID=<app uuid> ASS_PAGES=<page uuid>,<page uuid> build
```

## Related repositories

- **AssAndroid**: the Android library
- **AssBackend**: the API that receives the page views
- **AssFrontEnd**: the dashboard for viewing the stats

## Build

```bash
swift test                                                                       # tests, on the Mac
xcodebuild -scheme AnonymousSimpleStats -destination 'generic/platform=iOS Simulator' build
```

Requirements: Xcode 16 or newer (Swift 6).

## License

[MIT](LICENSE) © Clewig
