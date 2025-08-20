import SwiftUI
import SwiftData

struct MedicationView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var auth: AuthViewModel

    // Medication days (newest first)
    @Query(sort: \MedicationDay.date, order: .reverse)
    private var days: [MedicationDay]

    // Profiles (may be empty briefly on first load)
    @Query private var profiles: [UserProfile]

    @State private var today: MedicationDay?
    @State private var cachedProfile: UserProfile?

    private var currentProfile: UserProfile? {
        if let p = cachedProfile { return p }
        if let uid = auth.user?.uid,
           let byUID = profiles.first(where: { $0.authUID == uid }) {
            return byUID
        }
        return profiles.first
    }

    private var profileSyncToken: String {
        if let p = currentProfile {
            return "\(p.authUID)#\(p.dailyTablets)#\(p.dailyPuffs)#\(profiles.count)"
        }
        return "none#\(profiles.count)"
    }

    var body: some View {
        ZStack {
            // ✅ Full-screen background (no more narrow strip)
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // Header
                    VStack(spacing: 6) {
                        Text("BreatheWell")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.blue)

                        Text((today?.date ?? Date()).formatted(date: .complete, time: .omitted))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    if let t = today {
                        // Mockup-style ring that encloses the % label
                        AutoSizingProgressRing(
                            percent: t.adherence,
                            tablets: t.tabletsPrescribed,
                            puffs: t.puffsPrescribed
                        )
                        .padding(.top, 2)

                        // Tablets row
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(t.tabletsTaken)/\(t.tabletsPrescribed)")
                                .font(.headline)

                            CapsuleRow(
                                total: t.tabletsPrescribed,
                                filled: t.tabletsTaken,
                                iconName: "pills"
                            ) { idx in
                                if idx < t.tabletsTaken {
                                    t.tabletsTaken = max(0, idx)
                                } else {
                                    t.tabletsTaken = min(t.tabletsPrescribed, idx + 1)
                                }
                                try? context.save()
                            }
                        }

                        // Inhaler row
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(t.puffsTaken)/\(t.puffsPrescribed)")
                                .font(.headline)

                            CapsuleRow(
                                total: t.puffsPrescribed,
                                filled: t.puffsTaken,
                                iconName: "lungs.fill" // use "wind" if needed on older targets
                            ) { idx in
                                if idx < t.puffsTaken {
                                    t.puffsTaken = max(0, idx)
                                } else {
                                    t.puffsTaken = min(t.puffsPrescribed, idx + 1)
                                }
                                try? context.save()
                            }
                        }

                        Text("Tap an icon to mark tablets or inhaler puffs taken.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                            .padding(.bottom, 24)
                    } else {
                        ProgressView("Loading…")
                            .padding(.vertical, 80)
                    }
                }
                // Keep the centered column feel, but background is now on ZStack
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .background(.clear) // important so the ScrollView doesn't repaint a strip
        }
        .navigationBarHidden(true)

        // Bootstrap & resync
        .task {
            await ensureProfileExists()
            await ensureTodayMatchesProfile()
        }
        .onAppear {
            Task {
                await ensureProfileExists()
                await ensureTodayMatchesProfile()
            }
        }
        .onChange(of: auth.user?.uid) { _, _ in
            Task {
                cachedProfile = nil
                await ensureProfileExists()
                await ensureTodayMatchesProfile()
            }
        }
        .onChange(of: profileSyncToken) { _, _ in
            Task { await ensureTodayMatchesProfile() }
        }
    }

    // MARK: Profile bootstrap
    @MainActor
    private func ensureProfileExists() async {
        if cachedProfile != nil { return }
        guard let uid = auth.user?.uid else { return }

        if let found = profiles.first(where: { $0.authUID == uid }) {
            cachedProfile = found
            return
        }
        if let found = try? context.fetch(FetchDescriptor<UserProfile>())
            .first(where: { $0.authUID == uid }) {
            cachedProfile = found
            return
        }
        let p = UserProfile(
            authUID: uid,
            displayName: auth.user?.displayName ?? "",
            email: auth.user?.email,
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
        try? context.save()
        cachedProfile = p
        print("✅ Created UserProfile for MedicationView uid:", uid)
    }

    // MARK: Ensure “today” exists & matches profile defaults
    @MainActor
    private func ensureTodayMatchesProfile() async {
        let prof = currentProfile

        if let t = today, Calendar.current.isDateInToday(t.date) {
            applyProfileDefaults(to: t, profile: prof)
            return
        }
        if let existing = days.first(where: { Calendar.current.isDateInToday($0.date) }) {
            today = existing
            applyProfileDefaults(to: existing, profile: prof)
            return
        }
        // Create new
        let tabs = prof?.dailyTablets ?? 5
        let puffs = prof?.dailyPuffs ?? 3
        let m = MedicationDay(
            date: Date(),
            tabletsPrescribed: tabs,
            tabletsTaken: 0,
            puffsPrescribed: puffs,
            puffsTaken: 0
        )
        context.insert(m)
        try? context.save()
        today = m
    }

    private func applyProfileDefaults(to m: MedicationDay, profile: UserProfile?) {
        guard let prof = profile else { return }
        var changed = false
        if m.tabletsPrescribed != prof.dailyTablets {
            m.tabletsPrescribed = prof.dailyTablets
            m.tabletsTaken = min(m.tabletsTaken, m.tabletsPrescribed)
            changed = true
        }
        if m.puffsPrescribed != prof.dailyPuffs {
            m.puffsPrescribed = prof.dailyPuffs
            m.puffsTaken = min(m.puffsTaken, m.puffsPrescribed)
            changed = true
        }
        if changed { try? context.save() }
    }
}

// MARK: - Auto-sizing mockup ring (thin track, big %)
private struct AutoSizingProgressRing: View {
    let percent: Double   // 0.0 ... 1.0
    let tablets: Int
    let puffs: Int

    var body: some View {
        GeometryReader { geo in
            let maxW = geo.size.width
            let ringSize = min(maxW, 320)      // large but capped
            let ringWidth = ringSize * 0.055    // ~ thin ring (≈ 14–18 px)
            let percentFont = ringSize * 0.24   // big % like mockup

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.12), lineWidth: ringWidth)

                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, percent))))
                    .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: percent)

                VStack(spacing: 8) {
                    Text("\(Int(round(percent * 100)))%")
                        .font(.system(size: percentFont, weight: .bold, design: .rounded))

                    Text("of \(tablets) tablets &\n\(puffs) inhaler puffs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity) // centered within GeometryReader
        }
        .frame(height: 300) // enough vertical room for large devices
    }
}

// MARK: - Capsule row (soft look like mock)
private struct CapsuleRow: View {
    let total: Int
    let filled: Int
    let iconName: String
    var onTapIndex: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                Button {
                    onTapIndex(i)
                } label: {
                    Image(systemName: iconName)
                        .imageScale(.large)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(i < filled ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        )
    }
}
