import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @State private var breathlessness = 0
    @State private var cough = ""
    @State private var energyLevel = 5
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Daily Symptoms")) {
                    Picker("Breathlessness", selection: $breathlessness) {
                        ForEach(0..<11) { Text("\($0)") }
                    }
                    
                    TextField("Cough description", text: $cough)
                    
                    Stepper("Energy: \(energyLevel)", value: $energyLevel, in: 1...10)
                }
                
                Button("Save Entry") {
                    let entry = SymptomEntry(
                        breathlessness: breathlessness,
                        cough: cough,
                        energyLevel: energyLevel
                    )
                    context.insert(entry)
                    try? context.save()
                    
                    // Clear form after saving
                    breathlessness = 0
                    cough = ""
                    energyLevel = 5
                }
            }
            .navigationTitle("Log Symptoms")
        }
    }
}
