import Foundation
import SwiftData

@Model
final class ForumPost {
    var id: UUID
    var createdAt: Date
    var authorDisplayName: String
    var authorAvatar: String       // SF Symbol name
    var text: String
    var likeCount: Int
    @Relationship(deleteRule: .cascade) var comments: [ForumComment]

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         authorDisplayName: String,
         authorAvatar: String,
         text: String,
         likeCount: Int = 0,
         comments: [ForumComment] = []) {
        self.id = id
        self.createdAt = createdAt
        self.authorDisplayName = authorDisplayName
        self.authorAvatar = authorAvatar
        self.text = text
        self.likeCount = likeCount
        self.comments = comments
    }
}

@Model
final class ForumComment {
    var id: UUID
    var createdAt: Date
    var authorDisplayName: String
    var authorAvatar: String
    var text: String

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         authorDisplayName: String,
         authorAvatar: String,
         text: String) {
        self.id = id
        self.createdAt = createdAt
        self.authorDisplayName = authorDisplayName
        self.authorAvatar = authorAvatar
        self.text = text
    }
}
