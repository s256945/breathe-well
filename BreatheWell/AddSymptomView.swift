import SwiftUI
import SwiftData

struct AddSymptomView: View {
    @Environment(\.modelContext) private var context

    @State private var breathlessness = 0
    @State private var cough = ""
    @State private var energyLevel = 5

    var body: some View {
        VStack {
            // Header
            Text("BreatheWell").font(.title2).fontWeight(.semibold).foregroundStyle(.blue)
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.headline).foregroundStyle(.secondary)

            // Form
            Form {
                Section("Daily Symptoms") {
                    Picker("Breathlessness", selection: $breathlessness) {
                        ForEach(0..<11) { Text("\($0)") }
                    }
                    TextField("Cough description", text: $cough)
                    Stepper("Energy: \(energyLevel)", value: $energyLevel, in: 1...10)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)

            // Bottom action bar
            HStack {
                Button(role: .cancel) {
                    // reset fields
                    breathlessness = 0; cough = ""; energyLevel = 5
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                }

                Spacer()

                Button {
                    let entry = SymptomEntry(
                        breathlessness: breathlessness,
                        cough: cough,
                        energyLevel: energyLevel
                    )
                    context.insert(entry)
                    try? context.save()
                    // clear after save
                    breathlessness = 0; cough = ""; energyLevel = 5
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .padding(.top, 16)
    }
}
