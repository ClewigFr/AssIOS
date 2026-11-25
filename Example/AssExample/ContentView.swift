import AnonymousSimpleStats
import SwiftUI

struct ContentView: View {
    let stats: AnonymousSimpleStatsManager
    @State private var logged = 0

    var body: some View {
        let content = List {
            Section {
                LabeledContent("Endpoint", value: ExampleConfig.endpoint)
                LabeledContent("App", value: ExampleConfig.appId)
                LabeledContent("Logged", value: "\(logged)")
                    .accessibilityIdentifier("logged")
            }
            Section {
                if ExampleConfig.pages.isEmpty {
                    Text("No page: set ASS_PAGES to comma-separated page UUIDs from the dashboard.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(ExampleConfig.pages.enumerated()), id: \.offset) { index, page in
                    Button("Log page \(index + 1)") { log(page) }
                        .accessibilityIdentifier("log_page_\(index + 1)")
                }
                if !ExampleConfig.pages.isEmpty {
                    Button("Log 25 views") {
                        for i in 0..<25 { log(ExampleConfig.pages[i % ExampleConfig.pages.count]) }
                    }
                    .accessibilityIdentifier("log_25")
                }
            }
        }
        .navigationTitle("Anonymous Simple Stats")

        NavigationStack {
            if let first = ExampleConfig.pages.first {
                // Logged when shown and each time the app comes back to the foreground
                content.trackScreen(stats, first)
            } else {
                content
            }
        }
    }

    private func log(_ page: String) {
        stats.logScreen(page)
        logged += 1
    }
}
