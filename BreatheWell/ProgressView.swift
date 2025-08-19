import SwiftUI
import Charts
import SwiftData

struct ProgressView: View {
    // Correct @Query usage: specify the model type
    @Query(sort: \SymptomEntry.date, order: .forward) var entries: [SymptomEntry]

    var body: some View {
        Chart(entries) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("Breathlessness", entry.breathlessness)
            )
        }
        .padding()
        .navigationTitle("Progress")
    }
}
