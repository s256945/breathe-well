import SwiftUI

// MARK: - Model

struct BuddyMessage: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let date: Date
}

// MARK: - ViewModel (stubbed AI replies for now)

@MainActor
final class BreatheBuddyViewModel: ObservableObject {
    @Published var messages: [BuddyMessage] = [
        BuddyMessage(text: "Hey, I’m BreatheBuddy 👋\nI’m here for a friendly chat anytime. How’s your day going?", isUser: false, date: Date())
    ]
    @Published var input: String = ""
    @Published var isTyping: Bool = false

    // Quick-prompt chips (you can tweak freely)
    let suggestions = [
        "I feel a bit lonely",
        "Tell me a joke",
        "I went outside today",
        "Help me unwind",
        "Remind me to log symptoms"
    ]

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendUser(trimmed)
        input = ""
        reply(to: trimmed)
    }

    func tapSuggestion(_ text: String) {
        appendUser(text)
        reply(to: text)
    }

    private func appendUser(_ text: String) {
        messages.append(BuddyMessage(text: text, isUser: true, date: Date()))
    }

    // Very simple “AI”—replace later with a real API call
    private func reply(to userText: String) {
        isTyping = true

        Task {
            try? await Task.sleep(nanoseconds: 850_000_000) // typing delay

            let lower = userText.lowercased()
            let response: String

            if lower.contains("lonely") || lower.contains("alone") {
                response = """
                I’m really glad you told me. Feeling lonely can be heavy. 💙
                Want to try one tiny step that helps—maybe messaging someone in the Community, or noting one nice thing from today?
                """
            } else if lower.contains("joke") {
                response = "Here’s a tiny chuckle: Why did the cloud bring an umbrella? ☔️ Because of a chance of ‘reign’! Okay okay, I’m working on my material 😄"
            } else if lower.contains("outside") {
                response = "That’s awesome! A bit of fresh air can lift the whole day. 🌿 How did it feel?"
            } else if lower.contains("unwind") || lower.contains("relax") {
                response = "Try this: breathe in for 4, hold for 4, out for 6 — 5 times. Want me to count you through it?"
            } else if lower.contains("symptom") || lower.contains("log") {
                response = "Great idea. Keeping track helps you notice patterns. When you’re ready, tap the Symptoms tab to add today."
            } else if lower.contains("hi") || lower.contains("hello") {
                response = "Hi! 👋 What’s on your mind right now?"
            } else {
                response = "I’m listening. Tell me more — or pick a prompt below if that’s easier."
            }

            messages.append(BuddyMessage(text: response, isUser: false, date: Date()))
            isTyping = false
        }
    }
}

// MARK: - View

struct BreatheBuddyView: View {
    @StateObject private var vm = BreatheBuddyViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                                .padding(.horizontal, 12)
                        }

                        if vm.isTyping {
                            TypingBubble()
                                .padding(.horizontal, 12)
                        }

                        // Bottom padding to keep last bubble above the input
                        Color.clear.frame(height: 8)
                    }
                    .padding(.top, 8)
                }
                .background(Color(.systemGroupedBackground))
                .onChange(of: vm.messages) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        if let last = vm.messages.last?.id {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: vm.isTyping) { _, _ in
                    if let last = vm.messages.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            suggestionsBar

            inputBar
                .background(.bar)
        }
        .navigationTitle("BreatheBuddy")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text("BreatheBuddy")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
            Text("Your friendly companion")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var suggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.suggestions, id: \.self) { s in
                    Button {
                        vm.tapSuggestion(s)
                    } label: {
                        Text(s)
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(.blue)
                .opacity(0.7)

            TextField("Say anything…", text: $vm.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($inputFocused)

            Button {
                vm.send()
                inputFocused = false
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
            }
            .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: BuddyMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
                bubble(text: message.text, isUser: true)
                avatar(system: "person.circle.fill", tint: .blue.opacity(0.9))
            } else {
                avatar(system: "bubble.left.and.bubble.right.fill", tint: .green.opacity(0.9))
                bubble(text: message.text, isUser: false)
                Spacer(minLength: 40)
            }
        }
    }

    private func bubble(text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.body)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .background(isUser ? Color.accentColor : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func avatar(system name: String, tint: Color) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .foregroundStyle(tint)
    }
}

// MARK: - Typing Indicator

private struct TypingBubble: View {
    @State private var phase: Int = 0
    let dots = "•••"

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable().scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundStyle(.green.opacity(0.9))

            Text(dots.prefix(1 + (phase % 3)))
                .font(.headline)
                .monospaced()
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                        phase = 1
                    }
                    // Timer to animate dots
                    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        phase += 1
                    }
                }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

struct BreatheBuddyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BreatheBuddyView()
        }
    }
}
