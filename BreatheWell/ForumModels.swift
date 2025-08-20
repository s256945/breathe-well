import Foundation

struct ForumPost: Identifiable, Hashable, Codable {
    var id: String?
    var title: String
    var body: String
    var authorName: String
    var createdAt: Date
    var likeCount: Int
}

struct ForumComment: Identifiable, Hashable, Codable {
    var id: String?
    var body: String
    var authorName: String
    var createdAt: Date
    var likeCount: Int
}
