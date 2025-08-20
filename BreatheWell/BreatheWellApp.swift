import SwiftUI
import SwiftData

@main
struct BreatheWellApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(for: [SymptomEntry.self, MedicationDay.self])
        }
    }
}
