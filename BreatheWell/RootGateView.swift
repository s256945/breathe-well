import SwiftUI
import SwiftData

struct RootGateView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if let _ = auth.user {
                // Ensure a SwiftData profile exists for this user
                MainTabView()
                    .task(id: auth.user?.uid) {
                        if let u = auth.user {
                            auth.ensureLocalProfile(for: u, context: context)
                        }
                    }
            } else {
                AuthLandingView()
            }
        }
    }
}
