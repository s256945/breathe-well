import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var showConfirm = false
    @State private var isWorking = false

    // MARK: Validation
    private var emailIsValid: Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
    private var passwordIsValid: Bool { password.count >= 6 }
    private var passwordsMatch: Bool { !password.isEmpty && password == confirm }
    private var canSubmit: Bool {
        emailIsValid && passwordIsValid && passwordsMatch && !isWorking
    }

    var body: some View {
        Form {
            // Create account fields
            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)

                // Password with show/hide (no overlay — more stable)
                HStack {
                    if showPassword {
                        TextField("Password (min 6)", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.newPassword)
                    } else {
                        SecureField("Password (min 6)", text: $password)
                            .textContentType(.newPassword)
                    }
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    if showConfirm {
                        TextField("Confirm password", text: $confirm)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.newPassword)
                    } else {
                        SecureField("Confirm password", text: $confirm)
                            .textContentType(.newPassword)
                    }
                    Button { showConfirm.toggle() } label: {
                        Image(systemName: showConfirm ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Inline validation
                VStack(alignment: .leading, spacing: 6) {
                    if !email.isEmpty && !emailIsValid {
                        Label("Please enter a valid email address.", systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    if !password.isEmpty && !passwordIsValid {
                        Label("Password must be at least 6 characters.", systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    if !confirm.isEmpty && !passwordsMatch {
                        Label("Passwords don’t match.", systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                    }
                }
                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
            } header: {
                Text("Create account")
            }

            // Error section (wrap in Group to keep the builder happy)
            Group {
                if let err = auth.authError, !err.isEmpty {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text("Error")
                    }
                }
            }

            // Submit
            Section {
                Button {
                    Task { await createAccount() }
                } label: {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Create account").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .submitLabel(.go)
        .onSubmit {
            if canSubmit { Task { await createAccount() } }
        }
    }

    // MARK: Actions
    private func createAccount() async {
        guard canSubmit else { return }
        isWorking = true
        defer { isWorking = false }
        await auth.register(email: email.trimmingCharacters(in: .whitespaces),
                            password: password)
        if auth.user != nil { dismiss() }
    }
}
