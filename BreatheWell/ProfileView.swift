import SwiftUI
import SwiftData
import UserNotifications
import Foundation

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if let uid = auth.user?.uid {
            ProfileContent(uid: uid)
        } else {
            Text("Please sign in to manage your profile.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Resolves/creates the profile for the current Firebase UID
private struct ProfileContent: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var context

    let uid: String

    @Query private var profiles: [UserProfile]
    @State private var creating = false
    @State private var localProfile: UserProfile?
    @State private var lastError: String?

    var body: some View {
        if let profile = localProfile ?? profiles.first(where: { $0.authUID == uid }) {
            ProfileForm(profile: profile)
        } else {
            VStack(spacing: 12) {
                ProgressView("Preparing profile…")
                if let err = lastError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
            }
            .task(id: profiles.count) {
                await ensureLocalProfile()
            }
        }
    }

    @MainActor
    private func ensureLocalProfile() async {
        guard !creating else { return }
        creating = true
        defer { creating = false }

        do {
            if let found = profiles.first(where: { $0.authUID == uid }) {
                localProfile = found
                return
            }

            let all: [UserProfile] = try context.fetch(FetchDescriptor<UserProfile>())
            if let found = all.first(where: { $0.authUID == uid }) {
                localProfile = found
                return
            }

            // create new
            let u = auth.user
            let p = UserProfile(
                authUID: uid,
                displayName: u?.displayName ?? "",
                email: u?.email,
                yearOfBirth: nil,
                diagnosisNotes: nil,
                avatarSystemName: "person.circle.fill",
                dailyTablets: 0,
                dailyPuffs: 0,
                notificationsEnabled: true,
                reminderHour: 18,
                reminderMinute: 0
            )
            context.insert(p)
            try context.save()
            localProfile = p
        } catch {
            lastError = error.localizedDescription
        }
    }
}

// MARK: - The editable profile form
private struct ProfileForm: View {
    @EnvironmentObject var auth: AuthViewModel   // for Sign out
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    @State private var workingTime = Date()
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var years: [Int] { Array((currentYear - 120)...(currentYear - 18)).reversed() }

    var body: some View {
        Form {
            // MARK: Account
            Section(header: Text("Account")) {
                TextField("Display name", text: $profile.displayName)

                TextField("Email (optional)", text: Binding($profile.email, replacingNilWith: ""))
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

            // MARK: Forum Identity
            Section("Forum Identity") {
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
                            .resizable().scaledToFit()
                            .frame(width: 72, height: 72)
                            .foregroundStyle(.blue)
                        Text(profile.displayName.isEmpty ? "Anonymous" : profile.displayName)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            // MARK: Medication targets
            Section("Medication Targets") {
                Stepper("Daily tablets: \(profile.dailyTablets)",
                        value: $profile.dailyTablets, in: 0...20)
                    .onChange(of: profile.dailyTablets) { _, _ in
                        try? context.save()
                    }

                Stepper("Daily inhaler puffs: \(profile.dailyPuffs)",
                        value: $profile.dailyPuffs, in: 0...20)
                    .onChange(of: profile.dailyPuffs) { _, _ in
                        try? context.save()
                    }

                Text("These values populate the medication tracker by default each day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // MARK: Daily Reminder
            Section("Daily Reminder") {
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
                    Text("Scheduled for")
                    Spacer()
                    Text(profile.reminderTimeLabel).foregroundStyle(.secondary)
                }
            }

            // MARK: Data & Privacy
            Section("Data & Privacy") {
                Button {
                    // TODO: export CSV
                } label: {
                    Label("Export symptoms (CSV)", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }

            // MARK: About
            Section("About") {
                HStack { Text("App"); Spacer(); Text("BreatheWell").foregroundStyle(.secondary) }
                HStack { Text("Version"); Spacer(); Text(appVersionString()).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            // Backfill from Firebase if empty
            if profile.email == nil { profile.email = auth.user?.email }
            if profile.displayName.isEmpty, let n = auth.user?.displayName { profile.displayName = n }
            try? context.save()

            var comps = DateComponents()
            comps.hour = profile.reminderHour
            comps.minute = profile.reminderMinute
            workingTime = Calendar.current.date(from: comps) ?? Date()
        }
        .alert("Notifications", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(permissionMessage) }
    }

    // MARK: Helpers
    private func save() { try? context.save() }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) { granted,_ in
            DispatchQueue.main.async {
                permissionMessage = granted
                ? "Notifications enabled."
                : "Please enable notifications in Settings to receive reminders."
                showPermissionAlert = true
                if granted { scheduleDailyReminder() }
            }
        }
    }

    private func scheduleDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        var comps = DateComponents()
        comps.hour = profile.reminderHour
        comps.minute = profile.reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
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

// MARK: - Binding helpers
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

// MARK: - UserProfile conveniences
extension UserProfile {
    var reminderDateComponents: DateComponents { .init(hour: reminderHour, minute: reminderMinute) }
    var reminderTimeLabel: String {
        let df = DateFormatter(); df.timeStyle = .short
        if let d = Calendar.current.date(from: reminderDateComponents) { return df.string(from: d) }
        return "—"
    }
}
