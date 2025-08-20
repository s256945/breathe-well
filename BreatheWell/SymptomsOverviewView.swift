import SwiftUI
import SwiftData
import Charts

struct SymptomsOverviewView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SymptomEntry.date, order: .reverse) private var allEntries: [SymptomEntry]

    @State private var range: RangeFilter = .last7

    enum RangeFilter: String, CaseIterable, Identifiable {
        case last7 = "Last 7 days"
        case last14 = "Last 14 days"
        case last30 = "Last 30 days"

        var id: String { rawValue }
        var days: Int {
            switch self {
            case .last7:  return 7
            case .last14: return 14
            case .last30: return 30
            }
        }
    }

    private var todayString: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    private var filtered: [SymptomEntry] {
        guard let start = Calendar.current.date(byAdding: .day, value: -range.days + 1, to: .now) else { return [] }
        return allEntries.filter { $0.date >= Calendar.current.startOfDay(for: start) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Page title + brand
                        Text("Symptoms")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 6) {
                            Text("BreatheWell")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.blue)
                            Text(todayString)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        // Range picker
                        Picker("Range", selection: $range) {
                            ForEach(RangeFilter.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)

                        // Chart / placeholder card
                        Group {
                            if filtered.isEmpty {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                                    .overlay(
                                        Text("No entries yet")
                                            .foregroundStyle(.secondary)
                                            .font(.headline)
                                    )
                                    .frame(height: 220)
                            } else {
                                Chart(filtered, id: \.date) { entry in
                                    LineMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Breathlessness", entry.breathlessness)
                                    )
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Breathlessness", entry.breathlessness)
                                    )
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 5))
                                }
                                .frame(height: 220)
                                .padding(12)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }

                        // Actions (placeholders you can wire later)
                        HStack(spacing: 16) {
                            Button {
                                // TODO: generate a PDF/CSV and share
                            } label: {
                                Text("Download")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                // TODO: present UIPrintInteractionController
                            } label: {
                                Text("Print")
                            }
                            .buttonStyle(.bordered)
                            .disabled(filtered.isEmpty)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        Spacer(minLength: 100) // space so content doesn't clash with the floating button
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }

                // Floating Add button (above the tab bar)
                NavigationLink {
                    AddSymptomView()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .font(.system(size: 28, weight: .semibold))
                    }
                    .accessibilityLabel("Add symptom entry")
                }
                .buttonStyle(.plain)
                .padding(.bottom, 22)
                .frame(maxHeight: .infinity, alignment: .bottom) // stick to bottom center
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { /* no trailing add button anymore */ }
        }
    }
}
