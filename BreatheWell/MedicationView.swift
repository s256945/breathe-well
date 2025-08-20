import SwiftUI
import SwiftData

struct MedicationView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MedicationDay.date, order: .reverse)
    private var days: [MedicationDay]

    @State private var createdToday = false

    private var today: MedicationDay {
        if let existing = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: Date()) }) {
            return existing
        }
        if !createdToday {
            let m = MedicationDay()
            context.insert(m)
            try? context.save()
            createdToday = true
            return m
        }
        return MedicationDay()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("BreatheWell")
                    .font(.title2).fontWeight(.semibold).foregroundStyle(.blue)

                Text(today.date.formatted(date: .complete, time: .omitted))
                    .font(.headline).foregroundStyle(.secondary)

                // Big circular % gauge
                ZStack {
                    Gauge(value: today.adherence, in: 0...1) { }
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(.blue)
                        .frame(width: 220, height: 220)

                    VStack(spacing: 6) {
                        Text("\(Int(round(today.adherence * 100)))%")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("of \(today.tabletsPrescribed) tablets &\n\(today.puffsPrescribed) inhaler puffs")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                // Tablets row
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(today.tabletsTaken)/\(today.tabletsPrescribed)")
                        .font(.headline)

                    CapsuleRow(
                        total: today.tabletsPrescribed,
                        filled: today.tabletsTaken,
                        iconName: "pills"
                    ) { idx in
                        if idx < today.tabletsTaken {
                            today.tabletsTaken = max(0, idx)
                        } else {
                            today.tabletsTaken = min(today.tabletsPrescribed, idx + 1)
                        }
                        try? context.save()
                    }
                }
                .padding(.horizontal)

                // Inhaler row
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(today.puffsTaken)/\(today.puffsPrescribed)")
                        .font(.headline)

                    CapsuleRow(
                        total: today.puffsPrescribed,
                        filled: today.puffsTaken,
                        iconName: "lungs.fill" // if this SF Symbol isn't available on your iOS target, use "wind"
                    ) { idx in
                        if idx < today.puffsTaken {
                            today.puffsTaken = max(0, idx)
                        } else {
                            today.puffsTaken = min(today.puffsPrescribed, idx + 1)
                        }
                        try? context.save()
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }
}

// MARK: - CapsuleRow helper
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
                        .opacity(i < filled ? 1 : 0.25)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}
