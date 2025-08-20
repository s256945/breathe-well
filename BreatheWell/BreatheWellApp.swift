// BreatheWellApp.swift
import SwiftUI
import SwiftData
import FirebaseCore

@main
struct BreatheWellApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environmentObject(auth)   // ← important
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
