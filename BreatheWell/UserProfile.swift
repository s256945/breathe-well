import Foundation
import SwiftData

@Model
final class UserProfile {
    // MARK: Identity
    var displayName: String
    var email: String?
    var yearOfBirth: Int?
    var diagnosisNotes: String?

    // MARK: Forum identity (simple PFP using SF Symbols for now)
    var avatarSystemName: String

    // MARK: Clinician (optional)
    var clinicianName: String?
    var clinicName: String?

    // MARK: Medication defaults (used by Medication page)
    var dailyTablets: Int
    var dailyPuffs: Int

    // MARK: Reminders
    var notificationsEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    // MARK: - Initializer required by @Model
    init(
        displayName: String = "Your Name",
        email: String? = nil,
        yearOfBirth: Int? = nil,
        diagnosisNotes: String? = nil,
        avatarSystemName: String = "person.circle.fill",
        clinicianName: String? = nil,
        clinicName: String? = nil,
        dailyTablets: Int = 2,
        dailyPuffs: Int = 2,
        notificationsEnabled: Bool = true,
        reminderHour: Int = 18,
        reminderMinute: Int = 0
    ) {
        self.displayName = displayName
        self.email = email
        self.yearOfBirth = yearOfBirth
        self.diagnosisNotes = diagnosisNotes
        self.avatarSystemName = avatarSystemName
        self.clinicianName = clinicianName
        self.clinicName = clinicName
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
        let comps = reminderDateComponents
        let cal = Calendar.current
        let df = DateFormatter()
        df.timeStyle = .short
        return cal.date(from: comps).map { df.string(from: $0) } ?? "—"
    }
}
