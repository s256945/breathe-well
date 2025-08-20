import Foundation
import SwiftData

@Model
class MedicationDay {
    var date: Date
    var tabletsPrescribed: Int
    var tabletsTaken: Int
    var puffsPrescribed: Int
    var puffsTaken: Int

    init(date: Date = .init(),
         tabletsPrescribed: Int = 0,
         tabletsTaken: Int = 0,
         puffsPrescribed: Int = 0,
         puffsTaken: Int = 0) {
        self.date = date
        self.tabletsPrescribed = tabletsPrescribed
        self.tabletsTaken = tabletsTaken
        self.puffsPrescribed = puffsPrescribed
        self.puffsTaken = puffsTaken
    }

    var adherence: Double {
        let total = tabletsPrescribed + puffsPrescribed
        let done = tabletsTaken + puffsTaken
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }
}
