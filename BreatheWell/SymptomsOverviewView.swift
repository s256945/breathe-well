import SwiftUI
import SwiftData
import Charts

/// Choose which metric to draw
private enum SymptomMetric: String, CaseIterable, Identifiable {
    case breathlessness, energy, mood, sleep, loneliness
    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathlessness: return "Breathlessness"
        case .energy:         return "Energy"
        case .mood:           return "Mood"
        case .sleep:          return "Sleep"
        case .loneliness:     return "Loneliness"
        }
    }

    func value(from e: SymptomEntry) -> Double? {
        switch self {
        case .breathlessness: return Double(e.breathlessness)
        case .energy:         return Double(e.energyLevel)
        case .mood:           return Double(e.mood)
        case .sleep:          return Double(e.sleepQuality)
        case .loneliness:     return Double(e.loneliness)
        }
    }

    var yDomain: ClosedRange<Double> {
        switch self {
        case .breathlessness: return 0...10
        case .energy:         return 1...10
        case .mood, .sleep:   return 1...5
        case .loneliness:     return 0...2
        }
    }
}

private enum RangePick: String, CaseIterable, Identifiable {
    case last7 = "Last 7 days"
    case last30 = "Last 30 days"
    case last90 = "Last 90 days"
    var id: String { rawValue }

    var days: Int {
        switch self {
        case .last7:  return 7
        case .last30: return 30
        case .last90: return 90
        }
    }
}

struct SymptomsOverviewView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \SymptomEntry.date, order: .reverse)
    private var allEntries: [SymptomEntry]

    @State private var range: RangePick = .last7
    @State private var metric: SymptomMetric = .breathlessness
    @State private var showShare = false
    @State private var csvURL: URL?

    private var dateCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -range.days + 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var entries: [SymptomEntry] {
        allEntries.filter { $0.date >= dateCutoff }.sorted(by: { $0.date < $1.date })
    }

    private var averaged: [(date: Date, value: Double)] {
        let raw = entries.compactMap { e -> (Date, Double)? in
            guard let v = metric.value(from: e) else { return nil }
            return (e.date, v)
        }
        guard !raw.isEmpty else { return [] }
        let window = 3
        return raw.enumerated().map { i, pair in
            let lower = max(0, i - (window - 1))
            let slice = raw[lower...i].map { $0.1 }
            let avg = slice.reduce(0, +) / Double(slice.count)
            return (pair.0, avg)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("BreatheWell")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.blue)
                        Text(Date.now.formatted(date: .complete, time: .omitted))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        Menu {
                            Picker("Range", selection: $range) {
                                ForEach(RangePick.allCases) { r in Text(r.rawValue).tag(r) }
                            }
                        } label: {
                            Label(range.rawValue, systemImage: "calendar")
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                        }

                        Menu {
                            Picker("Metric", selection: $metric) {
                                ForEach(SymptomMetric.allCases) { m in Text(m.title).tag(m) }
                            }
                        } label: {
                            Label(metric.title, systemImage: "chart.xyaxis.line")
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                        }

                        Spacer()

                        Button {
                            if let url = exportCSV() {
                                csvURL = url
                                showShare = true
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(entries.isEmpty)
                    }
                    .padding(.horizontal)

                    Group {
                        if entries.isEmpty {
                            VStack(spacing: 10) {
                                Text("No entries yet")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Add daily symptoms to see your trends here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 280)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        } else {
                            Chart {
                                ForEach(entries, id: \.id) { e in
                                    if let v = metric.value(from: e) {
                                        LineMark(
                                            x: .value("Date", e.date),
                                            y: .value(metric.title, v)
                                        )
                                        .interpolationMethod(.monotone)
                                        PointMark(
                                            x: .value("Date", e.date),
                                            y: .value(metric.title, v)
                                        )
                                        .symbolSize(20)
                                    }
                                }
                                if averaged.count > 1 {
                                    ForEach(averaged, id: \.date) { p in
                                        LineMark(
                                            x: .value("Date", p.date),
                                            y: .value("Avg", p.value)
                                        )
                                        .foregroundStyle(.blue)
                                        .lineStyle(.init(lineWidth: 3))
                                        .interpolationMethod(.monotone)
                                    }
                                }
                            }
                            .chartYScale(domain: metric.yDomain)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                }
                            }
                            .frame(minHeight: 280)
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 12)

                    NavigationLink {
                        AddSymptomView()
                    } label: {
                        Label("Add today’s symptoms", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showShare) {
            if let csvURL {
                ShareSheet(items: [csvURL])
            }
        }
    }

    @discardableResult
    private func exportCSV() -> URL? {
        guard !entries.isEmpty else { return nil }
        var csv = "Date,Breathlessness,Energy,Mood,Sleep,Loneliness,Community,Outside,Note\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for e in entries {
            let d = df.string(from: e.date)
            let b = e.breathlessness
            let en = e.energyLevel
            let m = e.mood
            let s = e.sleepQuality
            let l = e.loneliness
            let c = e.hadCommunityInteraction ? "Yes" : "No"
            let o = e.wentOutside ? "Yes" : "No"
            let note = (e.gratitudeNote ?? "").replacingOccurrences(of: ",", with: " ")
            csv += "\(d),\(b),\(en),\(m),\(s),\(l),\(c),\(o),\(note)\n"
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Symptoms-\(UUID().uuidString.prefix(6)).csv")
            try csv.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            print("CSV write failed:", error)
            return nil
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
