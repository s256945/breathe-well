import SwiftUI
import SwiftData
import UserNotifications

/// Wrapper that ensures a single profile exists and then renders the editable form.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            ProfileForm(profile: profile)
        } else {
            // Create one immediately so we never get stuck on a loader
            ProfileForm(profile: ensureProfile())
        }
    }

    private func ensureProfile() -> UserProfile {
        let new = UserProfile()
        context.insert(new)
        try? context.save()
        return new
    }
}

// MARK: - Editable profile form

private struct ProfileForm: View {
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    @State private var workingTime = Date()
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    // 👇 Add these here
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var years: [Int] { Array((currentYear - 120)...(currentYear - 18)).reversed() }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Account
                Section(header: Text("Account")) {
                    TextField("Display name", text: $profile.displayName)

                    TextField("Email", text: Binding($profile.email, replacingNilWith: ""))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    Picker("Year of birth",
                           selection: Binding($profile.yearOfBirth, replacingNilWith: currentYear - 18)) {
                        ForEach(years, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // MARK: Forum identity
                Section(header: Text("Forum Identity")) {
                    Picker("Profile picture", selection: $profile.avatarSystemName) {
                        Label("Person", systemImage: "person.circle.fill").tag("person.circle.fill")
                        Label("Heart", systemImage: "heart.fill").tag("heart.fill")
                        Label("Leaf", systemImage: "leaf.fill").tag("leaf.fill")
                        Label("Star", systemImage: "star.fill").tag("star.fill")
                        Label("Bolt", systemImage: "bolt.fill").tag("bolt.fill")
                        Label("Sun", systemImage: "sun.max.fill").tag("sun.max.fill")
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: profile.avatarSystemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .foregroundStyle(.blue)
                                .shadow(radius: 1)
                            Text(profile.displayName.isEmpty ? "Anonymous" : profile.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                // MARK: Clinician (optional)
                Section(header: Text("Clinician")) {
                    TextField("Clinician name", text: Binding($profile.clinicianName, replacingNilWith: ""))
                    TextField("Clinic / hospital", text: Binding($profile.clinicName, replacingNilWith: ""))
                }

                // MARK: Medication defaults
                Section(header: Text("Medication Defaults")) {
                    Stepper("Daily tablets: \(profile.dailyTablets)",
                            value: $profile.dailyTablets,
                            in: 0...20)
                    Stepper("Daily inhaler puffs: \(profile.dailyPuffs)",
                            value: $profile.dailyPuffs,
                            in: 0...20)
                    Text("These values populate the medication tracker by default each day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // MARK: Daily reminder
                Section(header: Text("Daily Reminder")) {
                    Toggle("Enable notifications", isOn: $profile.notificationsEnabled)
                        .onChange(of: profile.notificationsEnabled) { _, newVal in
                            if newVal {
                                requestNotificationPermission()
                            } else {
                                cancelDailyReminder()
                            }
                            save()
                        }

                    DatePicker("Reminder time",
                               selection: $workingTime,
                               displayedComponents: .hourAndMinute)
                        .onChange(of: workingTime) { _, newVal in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newVal)
                            profile.reminderHour = comps.hour ?? 18
                            profile.reminderMinute = comps.minute ?? 0
                            save()
                            if profile.notificationsEnabled { scheduleDailyReminder() }
                        }
                        .disabled(!profile.notificationsEnabled)

                    HStack {
                        Text("Scheduled for")
                        Spacer()
                        Text(profile.reminderTimeLabel).foregroundStyle(.secondary)
                    }
                }

                // MARK: Data & Privacy
                Section(header: Text("Data & Privacy")) {
                    Button {
                        exportSymptomCSV()
                    } label: {
                        Label("Export symptoms (CSV)", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        deleteAllDataPrompt()
                    } label: {
                        Label("Delete all local data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // MARK: About
                Section(header: Text("About")) {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("BreatheWell").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString()).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                // initialise workingTime from stored hour/minute
                var comps = DateComponents()
                comps.hour = profile.reminderHour
                comps.minute = profile.reminderMinute
                workingTime = Calendar.current.date(from: comps) ?? Date()
            }
            .alert("Notifications", isPresented: $showPermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(permissionMessage)
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        try? context.save()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    scheduleDailyReminder()
                    permissionMessage = "Notifications enabled."
                } else {
                    permissionMessage = "Please enable notifications in Settings to receive reminders."
                }
                showPermissionAlert = true
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

    private func exportSymptomCSV() {
        // Placeholder – implement real export later
    }

    private func deleteAllDataPrompt() {
        // Placeholder – implement a confirmation flow + purge later
    }

    private func appVersionString() -> String {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Binding helpers for optionals

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

extension Binding where Value == Int {
    init(_ source: Binding<Int?>, replacingNilWith defaultValue: Int) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue
            }
        )
    }
}
