import Foundation

struct ForumPost: Identifiable, Hashable {
    var id: String?
    var title: String
    var body: String
    var authorId: String
    var authorName: String
    var authorAvatar: String
    var createdAt: Date
    var likeCount: Int
}

struct ForumComment: Identifiable, Hashable {
    var id: String?
    var body: String
    var authorId: String
    var authorName: String
    var authorAvatar: String
    var createdAt: Date
    var likeCount: Int
}
