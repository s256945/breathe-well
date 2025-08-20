import Foundation

struct ChatMessage: Identifiable, Codable {
    var id: String?
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
}
