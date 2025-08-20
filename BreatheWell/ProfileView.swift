import SwiftUI
import SwiftData
import UserNotifications

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("profileID") private var profileIDString = ""

    // Fetch all profiles; we’ll pick the one with the stored UUID
    @Query private var profiles: [UserProfile]

    // Local fallback after we create a new profile
    @State private var fallbackProfile: UserProfile?

    // Resolve the profile to show
    private var boundProfile: UserProfile? {
        // Prefer the stored UUID if available
        if let id = UUID(uuidString: profileIDString),
           let exact = profiles.first(where: { $0.id == id }) {
            return exact
        }
        // Else if we just created one in this view
        if let created = fallbackProfile { return created }
        // Else fall back to any existing profile (shouldn’t happen after register)
        return profiles.first
    }

    var body: some View {
        Group {
            if let profile = boundProfile {
                ProfileForm(profile: profile)
            } else {
                // Last resort: create, store its id, then show
                ProgressView("Preparing profile…")
                    .task {
                        // Double-check again in case it appeared meanwhile
                        if boundProfile == nil {
                            let new = UserProfile()
                            context.insert(new)
                            try? context.save()
                            // Update @AppStorage on the main actor
                            await MainActor.run {
                                profileIDString = new.id.uuidString
                                fallbackProfile = new
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Form stays the same, binds to @Bindable profile

private struct ProfileForm: View {
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    @State private var workingTime = Date()
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var years: [Int] { Array((currentYear - 120)...(currentYear - 18)).reversed() }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account")) {
                    TextField("Display name", text: $profile.displayName)

                    TextField("Email (optional)", text: Binding($profile.email, replacingNilWith: ""))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    Picker("Year of birth",
                           selection: Binding($profile.yearOfBirth, replacingNilWith: currentYear - 18)) {
                        ForEach(years, id: \.self) { y in Text(String(y)).tag(y) }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section(header: Text("Forum Identity")) {
                    Picker("Profile picture", selection: $profile.avatarSystemName) {
                        Label("Person", systemImage: "person.circle.fill").tag("person.circle.fill")
                        Label("Heart", systemImage: "heart.fill").tag("heart.fill")
                        Label("Leaf", systemImage: "leaf.fill").tag("leaf.fill")
                        Label("Star", systemImage: "star.fill").tag("star.fill")
                        Label("Bolt", systemImage: "bolt.fill").tag("bolt.fill")
                        Label("Sun", systemImage: "sun.max.fill").tag("sun.max.fill")
                    }.pickerStyle(.menu)

                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: profile.avatarSystemName)
                                .resizable().scaledToFit().frame(width: 72, height: 72)
                                .foregroundStyle(.blue)
                            Text(profile.displayName.isEmpty ? "Anonymous" : profile.displayName)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                Section(header: Text("Medication Defaults")) {
                    Stepper("Daily tablets: \(profile.dailyTablets)", value: $profile.dailyTablets, in: 0...20)
                    Stepper("Daily inhaler puffs: \(profile.dailyPuffs)", value: $profile.dailyPuffs, in: 0...20)
                    Text("These values populate the medication tracker by default each day.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section(header: Text("Daily Reminder")) {
                    Toggle("Enable notifications", isOn: $profile.notificationsEnabled)
                        .onChange(of: profile.notificationsEnabled) { _, on in
                            if on { requestNotificationPermission() } else { cancelDailyReminder() }
                            save()
                        }

                    DatePicker("Reminder time", selection: $workingTime, displayedComponents: .hourAndMinute)
                        .onChange(of: workingTime) { _, t in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: t)
                            profile.reminderHour = comps.hour ?? 18
                            profile.reminderMinute = comps.minute ?? 0
                            save()
                            if profile.notificationsEnabled { scheduleDailyReminder() }
                        }
                        .disabled(!profile.notificationsEnabled)

                    HStack {
                        Text("Scheduled for"); Spacer()
                        Text(profile.reminderTimeLabel).foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Data & Privacy")) {
                    Button { /* TODO: export */ } label: {
                        Label("Export symptoms (CSV)", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        // Simple sign-out (keeps local data)
                        UserDefaults.standard.set(false, forKey: "signedIn")
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }

                Section(header: Text("About")) {
                    HStack { Text("App"); Spacer(); Text("BreatheWell").foregroundStyle(.secondary) }
                    HStack { Text("Version"); Spacer(); Text(appVersionString()).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                var comps = DateComponents()
                comps.hour = profile.reminderHour
                comps.minute = profile.reminderMinute
                workingTime = Calendar.current.date(from: comps) ?? Date()
            }
            .alert("Notifications", isPresented: $showPermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(permissionMessage) }
        }
    }

    // Helpers
    private func save() { try? context.save() }
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) { granted,_ in
            DispatchQueue.main.async {
                permissionMessage = granted ? "Notifications enabled." :
                    "Please enable notifications in Settings to receive reminders."
                showPermissionAlert = true
                if granted { scheduleDailyReminder() }
            }
        }
    }
    private func scheduleDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        let trigger = UNCalendarNotificationTrigger(dateMatching: profile.reminderDateComponents, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Log your symptoms"
        content.body = "It only takes a minute."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
    private func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
    private func appVersionString() -> String {
        let d = Bundle.main.infoDictionary
        let v = d?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = d?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// Binding helpers
extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue },
                  set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
extension Binding where Value == Int {
    init(_ source: Binding<Int?>, replacingNilWith defaultValue: Int) {
        self.init(get: { source.wrappedValue ?? defaultValue },
                  set: { source.wrappedValue = $0 })
    }
}
