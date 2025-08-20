import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var newMessageText: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    /// How many messages to keep live (tune as you wish)
    private let pageSize = 200

    init() {
        listenForMessages()
    }

    deinit {
        listener?.remove()
    }

    // Live updates ordered by timestamp
    func listenForMessages() {
        listener?.remove()

        listener = db.collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let docs = snapshot?.documents else { return }
                self.messages = docs.compactMap { try? $0.data(as: ChatMessage.self) }
            }
    }

    // Send a text message
    func sendMessage(displayNameFallback: String? = nil) {
        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "You must be signed in to send messages."
            return
        }

        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        errorMessage = nil

        // Compose document data (rules validate these fields)
        let data: [String: Any] = [
            "senderId": user.uid,
            "senderName": (user.displayName ?? displayNameFallback ?? "Anonymous"),
            "text": text,
            // Using client time keeps the model as `Date`; rules still verify it's a timestamp.
            // If you prefer server time, use FieldValue.serverTimestamp() and make ChatMessage.timestamp optional.
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("messages").addDocument(data: data) { [weak self] err in
            guard let self else { return }
            self.isSending = false
            if let err = err {
                self.errorMessage = err.localizedDescription
            } else {
                self.newMessageText = ""
            }
        }
    }
}
