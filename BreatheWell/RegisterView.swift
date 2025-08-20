import SwiftUI
import SwiftData

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("signedIn") private var signedIn = false
    @AppStorage("profileID") private var profileIDString = ""   // ← remember which profile
    @Query private var profiles: [UserProfile]

    @State private var displayName = ""
    @State private var email = ""
    @State private var yearOfBirth = Calendar.current.component(.year, from: Date()) - 18
    @State private var avatarSystemName = "person.circle.fill"
    @State private var agree = false

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var years: [Int] { Array((currentYear - 120)...(currentYear - 18)).reversed() }

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && agree
    }

    var body: some View {
        Form {
            Section("Create account") {
                TextField("Display name", text: $displayName)
                TextField("Email (optional)", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                Picker("Year of birth", selection: $yearOfBirth) {
                    ForEach(years, id: \.self) { y in Text(String(y)).tag(y) }
                }.pickerStyle(.navigationLink)

                Picker("Avatar", selection: $avatarSystemName) {
                    Label("Person", systemImage: "person.circle.fill").tag("person.circle.fill")
                    Label("Heart", systemImage: "heart.fill").tag("heart.fill")
                    Label("Leaf", systemImage: "leaf.fill").tag("leaf.fill")
                    Label("Star", systemImage: "star.fill").tag("star.fill")
                    Label("Bolt", systemImage: "bolt.fill").tag("bolt.fill")
                    Label("Sun", systemImage: "sun.max.fill").tag("sun.max.fill")
                }.pickerStyle(.menu)

                HStack {
                    Spacer()
                    Image(systemName: avatarSystemName)
                        .resizable().scaledToFit().frame(width: 56, height: 56)
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }

            Section("Consent") {
                Toggle("I am 18+ and agree to the Terms & Privacy Policy", isOn: $agree)
            }

            Section {
                Button("Create account") { createOrUpdateProfile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // If returning user, prefill
            if let p = profiles.first {
                displayName = p.displayName
                email = p.email ?? ""
                yearOfBirth = p.yearOfBirth ?? (currentYear - 18)
                avatarSystemName = p.avatarSystemName
            }
        }
    }

    private func createOrUpdateProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        var profile: UserProfile
        if let existing = profiles.first {
            existing.displayName = trimmedName
            existing.email = trimmedEmail.isEmpty ? nil : trimmedEmail
            existing.yearOfBirth = yearOfBirth
            existing.avatarSystemName = avatarSystemName
            profile = existing
        } else {
            profile = UserProfile(
                displayName: trimmedName,
                email: trimmedEmail.isEmpty ? nil : trimmedEmail,
                yearOfBirth: yearOfBirth,
                avatarSystemName: avatarSystemName
            )
            context.insert(profile)
        }

        try? context.save()

        // Persist which profile to use + signed-in state
        profileIDString = profile.id.uuidString
        signedIn = true

        dismiss() // go into the app
    }
}
