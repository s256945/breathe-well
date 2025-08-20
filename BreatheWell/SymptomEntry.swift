import Foundation
import SwiftData

@Model
final class SymptomEntry: Identifiable {
    // Core
    var id = UUID()
    var date: Date

    // Physical symptoms
    var breathlessness: Int        // 0–10
    var cough: String
    var energyLevel: Int           // 1–10

    // Wellbeing & social (NEW)
    var mood: Int                  // 1–5 (1=very low, 5=very good)
    var loneliness: Int            // 0=Never, 1=Sometimes, 2=Often
    var sleepQuality: Int          // 1–5
    var hadCommunityInteraction: Bool
    var wentOutside: Bool
    var gratitudeNote: String?

    init(
        date: Date = Date(),
        breathlessness: Int = 0,
        cough: String = "",
        energyLevel: Int = 1,
        mood: Int = 1,
        loneliness: Int = 1,
        sleepQuality: Int = 1,
        hadCommunityInteraction: Bool = false,
        wentOutside: Bool = false,
        gratitudeNote: String? = nil
    ) {
        self.date = date
        self.breathlessness = breathlessness
        self.cough = cough
        self.energyLevel = energyLevel
        self.mood = mood
        self.loneliness = loneliness
        self.sleepQuality = sleepQuality
        self.hadCommunityInteraction = hadCommunityInteraction
        self.wentOutside = wentOutside
        self.gratitudeNote = gratitudeNote
    }
}
