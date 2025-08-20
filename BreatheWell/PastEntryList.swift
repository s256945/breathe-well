import SwiftUI
import SwiftData

struct PastEntryList: View {
    @Query(sort: \SymptomEntry.date, order: .reverse) var entries: [SymptomEntry]

    var body: some View {
        if entries.isEmpty {
            Text("No past logs yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            List(entries) { entry in
                VStack(alignment: .leading) {
                    Text(entry.date, style: .date).font(.headline)
                    Text("Breathlessness: \(entry.breathlessness)")
                    Text("Cough: \(entry.cough)")
                    Text("Energy: \(entry.energyLevel)")
                }
            }
        }
    }
}
