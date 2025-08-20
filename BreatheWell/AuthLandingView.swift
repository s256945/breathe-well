// AuthLandingView.swift
import SwiftUI

struct AuthLandingView: View {
    @State private var showRegister = false
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 10) {
                        Text("BreatheWell")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("Support that meets you where you are")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Text("Track symptoms. Stay on top of medication.\nFeel supported by a kind community.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal)

                    Image(systemName: "lungs.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                        .padding(.top, 8)

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            showRegister = true
                        } label: {
                            Text("Get started")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            showLogin = true
                        } label: {
                            Text("I already have an account")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)

                    Text("By continuing, you agree to our terms and privacy policy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .navigationDestination(isPresented: $showLogin) { LoginView() }
        }
    }
}
