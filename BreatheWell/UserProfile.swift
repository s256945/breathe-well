import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var authUID: String      // ✅ now non-optional
    var displayName: String
    var email: String?
    var yearOfBirth: Int?
    var diagnosisNotes: String?
    var avatarSystemName: String
    var dailyTablets: Int
    var dailyPuffs: Int
    var notificationsEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(
        authUID: String,
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
        self.authUID = authUID
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
