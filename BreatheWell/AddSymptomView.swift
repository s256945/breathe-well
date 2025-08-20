import SwiftUI
import SwiftData

struct AddSymptomView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss   // ← to go back

    // Physical
    @State private var breathlessness: Int = 0
    @State private var cough: String = ""
    @State private var energyLevel: Int = 5

    // Wellbeing & social
    @State private var mood: Int = 3                 // 1–5
    @State private var loneliness: Int = 1           // 0=Never,1=Sometimes,2=Often
    @State private var sleepQuality: Int = 3         // 1–5
    @State private var hadCommunityInteraction = false
    @State private var wentOutside = false
    @State private var gratitudeNote: String = ""

    private var prettyDate: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    private var canSave: Bool {
        breathlessness != 0 ||
        !cough.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        energyLevel != 5 ||
        mood != 3 ||
        loneliness != 1 ||
        sleepQuality != 3 ||
        hadCommunityInteraction ||
        wentOutside ||
        !gratitudeNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header (brand + date)
                        VStack(spacing: 8) {
                            Text("BreatheWell")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.blue)
                            Text(prettyDate)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)

                        // --- Physical symptoms ---
                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Breathlessness", systemImage: "lungs.fill")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(breathlessness)/10")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                VStack(spacing: 10) {
                                    Slider(value: Binding(
                                        get: { Double(breathlessness) },
                                        set: { breathlessness = Int($0.rounded()) }
                                    ), in: 0...10, step: 1)
                                    HStack {
                                        Text("None").font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("Worst").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Cough", systemImage: "waveform.path.ecg")
                                    .font(.headline)
                                TextField("Describe your cough (e.g. dry, productive, colour, frequency…)",
                                          text: $cough,
                                          axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3, reservesSpace: true)
                            }
                        }

                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Energy", systemImage: "bolt.fill")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(energyLevel)/10")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                Stepper("Energy level", value: $energyLevel, in: 1...10)
                                    .labelsHidden()
                                HStack(spacing: 6) {
                                    ForEach(1...10, id: \.self) { i in
                                        Circle()
                                            .frame(width: 8, height: 8)
                                            .foregroundStyle(i <= energyLevel ? Color.blue : Color.gray.opacity(0.25))
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }

                        // --- Wellbeing & social ---
                        CardSection {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Mood", systemImage: "face.smiling.fill")
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    ForEach(1...5, id: \.self) { i in
                                        Button {
                                            mood = i
                                        } label: {
                                            VStack(spacing: 6) {
                                                Text(emoji(forMood: i)).font(.title2)
                                                Text(moodLabel(i))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                        .padding(.vertical, 6)
                        .frame(width: 60)
                        .background(i == mood ? Color.blue.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Loneliness", systemImage: "person.fill.questionmark")
                                    .font(.headline)
                                Picker("", selection: $loneliness) {
                                    Text("Never").tag(0)
                                    Text("Sometimes").tag(1)
                                    Text("Often").tag(2)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Sleep quality", systemImage: "bed.double.fill")
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    ForEach(1...5, id: \.self) { i in
                                        Button {
                                            sleepQuality = i
                                        } label: {
                                            Image(systemName: i <= sleepQuality ? "star.fill" : "star")
                                                .font(.title3)
                                                .foregroundColor(i <= sleepQuality ? .blue : .gray.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        CardSection {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("I connected with someone today (chat/message/call/meet)", isOn: $hadCommunityInteraction)
                                Toggle("I went outside today", isOn: $wentOutside)
                            }
                        }

                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("One good thing from today", systemImage: "sparkles")
                                    .font(.headline)
                                TextField("Write a short note (optional)", text: $gratitudeNote, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3, reservesSpace: true)
                            }
                        }

                        Spacer(minLength: 48)
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)

                // Bottom action bar
                HStack {
                    // Cancel: clear & go back
                    Button(role: .cancel) {
                        reset()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44, weight: .regular))
                    }

                    Spacer()

                    // Save: insert, clear & go back
                    Button {
                        let entry = SymptomEntry(
                            breathlessness: breathlessness,
                            cough: cough.trimmingCharacters(in: .whitespacesAndNewlines),
                            energyLevel: energyLevel,
                            mood: mood,
                            loneliness: loneliness,
                            sleepQuality: sleepQuality,
                            hadCommunityInteraction: hadCommunityInteraction,
                            wentOutside: wentOutside,
                            gratitudeNote: gratitudeNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : gratitudeNote
                        )
                        context.insert(entry)
                        try? context.save()
                        reset()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44, weight: .regular))
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.35)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
        }
        .navigationBarHidden(true)
    }

    private func reset() {
        breathlessness = 0
        cough = ""
        energyLevel = 5
        mood = 3
        loneliness = 1
        sleepQuality = 3
        hadCommunityInteraction = false
        wentOutside = false
        gratitudeNote = ""
    }

    // Helpers for mood UI
    private func emoji(forMood value: Int) -> String {
        switch value {
        case 1: return "😞"
        case 2: return "🙁"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "😄"
        }
    }
    private func moodLabel(_ value: Int) -> String {
        switch value {
        case 1: return "Very low"
        case 2: return "Low"
        case 3: return "OK"
        case 4: return "Good"
        default: return "Very good"
        }
    }
}

// MARK: - Reusable card
private struct CardSection<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
