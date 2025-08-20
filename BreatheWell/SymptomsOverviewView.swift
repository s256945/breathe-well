import SwiftUI
import Charts
import SwiftData

struct SymptomsOverviewView: View {
    @Query(sort: \SymptomEntry.date, order: .forward) var entries: [SymptomEntry]
    @State private var range: RangeChoice = .last7

    enum RangeChoice: String, CaseIterable, Identifiable {
        case last7 = "Last 7 days"
        case last30 = "Last 30 days"
        case all = "All time"
        var id: String { rawValue }
    }

    var filtered: [SymptomEntry] {
        switch range {
        case .last7:
            let from = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return entries.filter { $0.date >= from }
        case .last30:
            let from = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            return entries.filter { $0.date >= from }
        case .all:
            return entries
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("BreatheWell")
                    .font(.title2).fontWeight(.semibold).foregroundStyle(.blue)
                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.headline).foregroundStyle(.secondary)

                Picker("Range", selection: $range) {
                    ForEach(RangeChoice.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Chart placeholder if empty
                if filtered.isEmpty {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 220)
                        .cornerRadius(12)
                        .overlay(Text("No entries yet").foregroundStyle(.secondary))
                        .padding(.horizontal)
                } else {
                    Chart(filtered) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Breathlessness", entry.breathlessness)
                        )
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Breathlessness", entry.breathlessness)
                        )
                    }
                    .frame(height: 240)
                    .padding(.horizontal)
                }

                Button("Download") { /* export image/PDF later */ }
                    .buttonStyle(.borderedProminent)

                Button("Print") { /* share sheet / print later */ }
                    .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.top, 12)
            .navigationTitle("Symptoms")
        }
    }
}
