import SwiftUI

@main
struct BreatheWellApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Log", systemImage: "square.and.pencil") }

                ProgressView()
                    .tabItem { Label("Progress", systemImage: "chart.bar") }
            }
        }
        .modelContainer(for: SymptomEntry.self) // enables SwiftData
    }
}
