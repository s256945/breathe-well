import Foundation
import SwiftData

@Model
class SymptomEntry: Identifiable {
    var id = UUID()
    var date: Date
    var breathlessness: Int       // 0–10
    var cough: String
    var energyLevel: Int          // 1–10

    init(date: Date = Date(),
         breathlessness: Int,
         cough: String,
         energyLevel: Int) {
        self.date = date
        self.breathlessness = breathlessness
        self.cough = cough
        self.energyLevel = energyLevel
    }
}
