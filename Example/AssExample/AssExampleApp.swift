import AnonymousSimpleStats
import SwiftUI

/// Demo / test bench for the library: one button per page logs a view of it, plus a button
/// that logs 25 views at once (more than the batch threshold). The first page is tracked with
/// `trackScreen`. Endpoint, application UUID and page UUIDs come from the build settings
/// ASS_ENDPOINT, ASS_APP_ID and ASS_PAGES, through Info.plist.
@main
struct AssExampleApp: App {
    let stats = AnonymousSimpleStatsManager.getInstance(
        AssConfig(
            endpoint: ExampleConfig.endpoint,
            // The application UUID shown in the dashboard ("Mes applications")
            appId: ExampleConfig.appId,
            verbose: true
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView(stats: stats)
        }
    }
}

enum ExampleConfig {
    static let endpoint = string("AssEndpoint")
    static let appId = string("AssAppId")
    static let pages = string("AssPages").split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    private static func string(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
