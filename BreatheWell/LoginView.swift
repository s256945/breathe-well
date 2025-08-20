// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section("Sign in") {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
            }

            if let err = auth.authError {
                Text(err).foregroundStyle(.red).font(.footnote)
            }

            Section {
                Button("Sign in") {
                    Task {
                        await auth.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                          password: password)
                        if auth.user != nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
    }
}
