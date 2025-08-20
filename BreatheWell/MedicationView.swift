import SwiftUI
import SwiftData

struct MedicationView: View {
    @Environment(\.modelContext) private var context

    // All medication days (newest first)
    @Query(sort: \MedicationDay.date, order: .reverse)
    private var days: [MedicationDay]

    // Single user profile (if any)
    @Query private var profiles: [UserProfile]

    @State private var createdToday = false

    private var profile: UserProfile? { profiles.first }

    // A key that changes when profile defaults change (to use in .onChange)
    private var profileDefaultsKey: String {
        let t = profile?.dailyTablets ?? -1
        let p = profile?.dailyPuffs ?? -1
        return "\(t)-\(p)"
    }

    // Find or create today's record
    private var today: MedicationDay {
        if let existing = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: Date()) }) {
            return existing
        }
        if !createdToday {
            let m = MedicationDay()
            if let p = profile {
                m.tabletsPrescribed = p.dailyTablets
                m.puffsPrescribed   = p.dailyPuffs
            }
            context.insert(m)
            try? context.save()
            createdToday = true
            return m
        }
        return MedicationDay()
    }

    // Apply current profile defaults to today (used onAppear and when profile changes)
    private func applyProfileDefaultsToToday() {
        guard let p = profile else { return }
        // Only change today's targets if they differ from profile
        if today.tabletsPrescribed != p.dailyTablets || today.puffsPrescribed != p.dailyPuffs {
            today.tabletsPrescribed = p.dailyTablets
            today.puffsPrescribed   = p.dailyPuffs
            // keep taken counts within new bounds
            today.tabletsTaken = min(today.tabletsTaken, today.tabletsPrescribed)
            today.puffsTaken   = min(today.puffsTaken, today.puffsPrescribed)
            try? context.save()
        }
    }

    // Nice date for header
    private var prettyDate: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMMM yyyy"
        return df.string(from: today.date)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {

                        // Header
                        VStack(spacing: 8) {
                            Text("BreatheWell")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.blue)

                            Text(prettyDate)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)

                        // Ring (behind text)
                        RingProgressView(progress: today.adherence) {
                            VStack(spacing: 6) {
                                Text("\(Int(round(today.adherence * 100)))%")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                Text("of \(today.tabletsPrescribed) tablets &\n\(today.puffsPrescribed) inhaler puffs")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(width: 260, height: 260)
                        .padding(.top, 4)

                        // Tablets row
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(today.tabletsTaken)/\(today.tabletsPrescribed)")
                                .font(.headline)

                            CapsuleContainer {
                                CapsuleRow(
                                    total: today.tabletsPrescribed,
                                    filled: today.tabletsTaken,
                                    filledIcon: "pills",
                                    emptyIcon: "pills"
                                ) { idx in
                                    if idx < today.tabletsTaken {
                                        today.tabletsTaken = max(0, idx)
                                    } else {
                                        today.tabletsTaken = min(today.tabletsPrescribed, idx + 1)
                                    }
                                    try? context.save()
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Inhaler row
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(today.puffsTaken)/\(today.puffsPrescribed)")
                                .font(.headline)

                            CapsuleContainer {
                                CapsuleRow(
                                    total: today.puffsPrescribed,
                                    filled: today.puffsTaken,
                                    filledIcon: "lungs.fill",
                                    emptyIcon: "lungs"
                                ) { idx in
                                    if idx < today.puffsTaken {
                                        today.puffsTaken = max(0, idx)
                                    } else {
                                        today.puffsTaken = min(today.puffsPrescribed, idx + 1)
                                    }
                                    try? context.save()
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 48)
                    }
                }
                .scrollIndicators(.hidden)

                // Bottom instructions
                VStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                    Text("Tap icons to mark tablets or inhaler puffs taken.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationBarHidden(true)
        // Seed/update when the view appears
        .onAppear {
            _ = today   // ensure it's created if needed
            applyProfileDefaultsToToday()
        }
        // Auto-apply if profile defaults change later
        .onChange(of: profileDefaultsKey) { _, _ in
            applyProfileDefaultsToToday()
        }
    }
}

// MARK: - Ring view (styled like your mockup)
private struct RingProgressView<Content: View>: View {
    var progress: Double // 0...1
    var content: () -> Content
    init(progress: Double, @ViewBuilder content: @escaping () -> Content) {
        self.progress = max(0, min(progress, 1))
        self.content = content
    }
    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
            content()
        }
    }
}

// MARK: - Capsule styles
private struct CapsuleContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack { content }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
    }
}

private struct CapsuleRow: View {
    let total: Int
    let filled: Int
    let filledIcon: String
    let emptyIcon: String
    var onTapIndex: (Int) -> Void
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                Button {
                    onTapIndex(i)
                } label: {
                    Image(systemName: i < filled ? filledIcon : emptyIcon)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(i < filled ? .blue : .gray.opacity(0.35))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
