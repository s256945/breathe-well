import SwiftUI
import SwiftData

@main
struct BreatheWellApp: App {
    @AppStorage("signedIn") private var signedIn = false

    var body: some Scene {
        WindowGroup {
            if signedIn {
                MainTabView()
            } else {
                AuthLandingView()
            }
        }
        .modelContainer(for: [
            SymptomEntry.self,
            MedicationDay.self,
            UserProfile.self,
            ForumPost.self,
            ForumComment.self
        ])
    }
}
