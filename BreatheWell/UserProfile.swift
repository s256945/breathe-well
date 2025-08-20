import Foundation
import SwiftData

@Model
final class UserProfile {
    // Stable identity we can store in @AppStorage
    var id: UUID

    // Identity
    var displayName: String
    var email: String?
    var yearOfBirth: Int?
    var diagnosisNotes: String?

    // Forum identity
    var avatarSystemName: String

    // Medication defaults
    var dailyTablets: Int
    var dailyPuffs: Int

    // Reminders
    var notificationsEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(
        id: UUID = UUID(),
        displayName: String = "",
        email: String? = nil,
        yearOfBirth: Int? = nil,
        diagnosisNotes: String? = nil,
        avatarSystemName: String = "person.circle.fill",
        dailyTablets: Int = 2,
        dailyPuffs: Int = 2,
        notificationsEnabled: Bool = true,
        reminderHour: Int = 18,
        reminderMinute: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.yearOfBirth = yearOfBirth
        self.diagnosisNotes = diagnosisNotes
        self.avatarSystemName = avatarSystemName
        self.dailyTablets = dailyTablets
        self.dailyPuffs = dailyPuffs
        self.notificationsEnabled = notificationsEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }
}

extension UserProfile {
    var reminderDateComponents: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }
    var reminderTimeLabel: String {
        let df = DateFormatter(); df.timeStyle = .short
        let comps = reminderDateComponents
        return Calendar.current.date(from: comps).map { df.string(from: $0) } ?? "—"
    }
}
