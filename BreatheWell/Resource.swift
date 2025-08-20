import Foundation
import SwiftData

enum ResourceType: String, Codable, CaseIterable, Identifiable {
    case exerciseVideo = "Exercise Video"
    case blog = "Blog"
    var id: String { rawValue }
}

@Model
class Resource {
    var title: String
    var author: String
    var isProfessional: Bool
    var type: String              // store as String for SwiftData (@Model enums are OK via Codable but this is simplest)
    var urlString: String
    var thumbnailURLString: String?
    var publishedAt: Date?
    var durationSeconds: Int?     // for videos

    init(title: String,
         author: String,
         isProfessional: Bool,
         type: ResourceType,
         urlString: String,
         thumbnailURLString: String? = nil,
         publishedAt: Date? = nil,
         durationSeconds: Int? = nil) {
        self.title = title
        self.author = author
        self.isProfessional = isProfessional
        self.type = type.rawValue
        self.urlString = urlString
        self.thumbnailURLString = thumbnailURLString
        self.publishedAt = publishedAt
        self.durationSeconds = durationSeconds
    }

    var url: URL? { URL(string: urlString) }
    var thumbnailURL: URL? { thumbnailURLString.flatMap(URL.init(string:)) }
    var resourceType: ResourceType { ResourceType(rawValue: type) ?? .blog }

    var durationLabel: String? {
        guard let s = durationSeconds else { return nil }
        let m = s / 60, sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
