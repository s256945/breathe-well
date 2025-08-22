import SwiftUI
import SwiftData
import Charts

// MARK: - Metric picker
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

// MARK: - Range picker
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

// Simple point model for Charts
private struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// Identifiable wrapper for share sheet
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct SymptomsOverviewView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \SymptomEntry.date, order: .reverse)
    private var allEntries: [SymptomEntry]

    @State private var range: RangePick = .last7
    @State private var metric: SymptomMetric = .breathlessness
    @State private var csvFile: ExportFile?          // <- use sheet(item:)
    
    // MARK: - Derived data

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }

    private var dateCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: todayStart) ?? todayStart
    }

    private var filteredEntries: [SymptomEntry] {
        let filtered = allEntries.filter { $0.date >= dateCutoff }
        return filtered.sorted { $0.date < $1.date }
    }

    private var points: [DataPoint] {
        var out: [DataPoint] = []
        out.reserveCapacity(filteredEntries.count)
        for e in filteredEntries {
            if let v = metric.value(from: e) {
                out.append(.init(date: e.date, value: v))
            }
        }
        return out
    }

    // Domain: first day start ... last day end (+60s nudge so last label appears)
    private var xDomain: ClosedRange<Date>? {
        guard let first = filteredEntries.first?.date,
              let last  = filteredEntries.last?.date else { return nil }
        let cal = Calendar.current
        let lower = cal.startOfDay(for: first)
        let endOfLast = cal.date(bySettingHour: 23, minute: 59, second: 59, of: last) ?? last
        return lower...(endOfLast.addingTimeInterval(60))
    }

    // One tick per unique entry day
    private var xTicks: [Date] {
        let cal = Calendar.current
        var set = Set<Date>()
        for e in filteredEntries { set.insert(cal.startOfDay(for: e.date)) }
        return Array(set).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 16) {
                    header
                    controls
                    chartArea
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
        // Present only when we have a real file URL
        .sheet(item: $csvFile) { file in
            ShareSheet(items: [file.url])
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Text("BreatheWell")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var controls: some View {
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
                    csvFile = ExportFile(url: url)   // <- trigger sheet
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(points.isEmpty)
        }
        .padding(.horizontal)
    }

    private var chartArea: some View {
        Group {
            if points.isEmpty {
                VStack(spacing: 10) {
                    Text("No entries yet").font(.headline).foregroundStyle(.secondary)
                    Text("Add daily symptoms to see your trends here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                buildChart()
                    .frame(minHeight: 280)
                    .padding(.horizontal)
            }
        }
    }

    // Build the chart step-by-step to avoid type-inference issues
    private func buildChart() -> AnyView {
        var view: AnyView = AnyView(
            Chart {
                ForEach(points) { p in
                    LineMark(x: .value("Date", p.date),
                             y: .value(metric.title, p.value))
                    PointMark(x: .value("Date", p.date),
                              y: .value(metric.title, p.value))
                }
            }
        )

        view = AnyView(view.chartYScale(domain: metric.yDomain))
        view = AnyView(view.chartYAxis { AxisMarks(position: .leading) })

        // X ticks only where we have data
        let ticks = xTicks
        view = AnyView(
            view.chartXAxis {
                AxisMarks(values: ticks) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        )

        if let domain = xDomain {
            view = AnyView(view.chartXScale(domain: domain))
        }

        return view
    }
    
    // MARK: - CSV export

    @discardableResult
    private func exportCSV() -> URL? {
        guard !filteredEntries.isEmpty else { return nil }
        var csv = "Date,Breathlessness,Energy,Mood,Sleep,Loneliness,Community,Outside,Note\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for e in filteredEntries {
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

// Share sheet wrapper
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
