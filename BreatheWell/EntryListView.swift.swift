import SwiftUI
import SwiftData

struct EntryListView: View {
    // Correct @Query syntax
    @Query(sort: \SymptomEntry.date, order: .reverse) var entries: [SymptomEntry]

    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading) {
                Text(entry.date, style: .date)
                    .font(.headline)
                Text("Breathlessness: \(entry.breathlessness)")
                Text("Cough: \(entry.cough)")
                Text("Energy: \(entry.energyLevel)")
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Past Entries")
    }
}
