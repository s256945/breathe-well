import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SymptomsOverviewView() // graph page
                .tabItem { Label("Symptoms", systemImage: "waveform.path.ecg") }

            ResourcesView()
                .tabItem { Label("Resources", systemImage: "book") }

            ForumView() //
                .tabItem { Label("Community", systemImage: "person.2.circle") }

            MedicationView()       // medication page (big % circle)
                .tabItem { Label("Medication", systemImage: "pills") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}
