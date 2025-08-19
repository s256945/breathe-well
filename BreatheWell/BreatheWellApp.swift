import SwiftUI
import SwiftData
import Charts

@main
struct BreatheWellApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Log", systemImage: "square.and.pencil") }

                ProgressView()
                    .tabItem { Label("Progress", systemImage: "chart.bar") }

                EntryListView()
                    .tabItem { Label("Past Logs", systemImage: "list.bullet") }
            }
            .modelContainer(for: [SymptomEntry.self])
        }
    }
}
