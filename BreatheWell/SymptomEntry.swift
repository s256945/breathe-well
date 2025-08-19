import Foundation
import SwiftData

@Model
class SymptomEntry {
    var date: Date
    var breathlessness: Int
    var cough: String
    var energyLevel: Int

    init(date: Date = Date(), breathlessness: Int, cough: String, energyLevel: Int) {
        self.date = date
        self.breathlessness = breathlessness
        self.cough = cough
        self.energyLevel = energyLevel
    }
}
