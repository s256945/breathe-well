import SwiftUI
import FirebaseAuth
import SwiftData

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User? = Auth.auth().currentUser
    @Published var authError: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // MARK: - Auth actions

    func register(email: String, password: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.user = result.user
            self.authError = nil
        } catch {
            self.authError = pretty(error: error)
            print("🔥 Firebase register error:", error)
        }
    }

    func signIn(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
            self.authError = nil
        } catch {
            self.authError = pretty(error: error)
            print("🔥 Firebase signIn error:", error)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            self.authError = pretty(error: error)
            print("🔥 Firebase signOut error:", error)
        }
    }

    // MARK: - Link Firebase user to local SwiftData profile

    /// Ensures there is exactly one local `UserProfile` linked to the given Firebase user.
    /// If a profile exists but is missing basic fields, this backfills them.
    func ensureLocalProfile(for user: FirebaseAuth.User, context: ModelContext) {
        let all: [UserProfile] = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []

        // 1) Exact match by authUID
        if let existingByUID = all.first(where: { $0.authUID == user.uid }) {
            if existingByUID.email == nil { existingByUID.email = user.email }
            if existingByUID.displayName.isEmpty, let n = user.displayName { existingByUID.displayName = n }
            try? context.save()
            return
        }

        // 2) Fallback: match by email (e.g. older installs created profile before auth)
        if let byEmail = all.first(where: { $0.email?.lowercased() == user.email?.lowercased() }) {
            byEmail.authUID = user.uid
            if byEmail.displayName.isEmpty, let n = user.displayName { byEmail.displayName = n }
            try? context.save()
            return
        }

        // 3) Create brand-new profile for this user
        let p = UserProfile(
            authUID: user.uid,
            displayName: user.displayName ?? "",
            email: user.email,
            yearOfBirth: nil,
            diagnosisNotes: nil,
            avatarSystemName: "person.circle.fill",
            dailyTablets: 2,
            dailyPuffs: 2,
            notificationsEnabled: true,
            reminderHour: 18,
            reminderMinute: 0
        )
        context.insert(p)
        try? context.save()
    }

    // MARK: - Error formatting

    private func pretty(error: Error) -> String {
        let ns = error as NSError
        let code = AuthErrorCode(rawValue: ns.code)
        switch code {
        case .emailAlreadyInUse: return "That email is already in use."
        case .invalidEmail:      return "That email address isn’t valid."
        case .weakPassword:      return "Password is too weak (minimum 6 characters)."
        case .networkError:      return "Network error - please check your connection and try again."
        case .appNotAuthorized:  return "App not authorized for this Firebase project. Check Bundle ID & GoogleService-Info.plist."
        default:
            return ns.localizedDescription
        }
    }
}
