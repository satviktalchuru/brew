import SwiftUI

struct OnboardingView: View {
    var authService: AuthService
    var store: AppStore
    var onAuthComplete: () -> Void = {}

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""

    private var canSubmit: Bool {
        !isLoading && email.contains("@") && password.count >= 6
    }

    var body: some View {
        ZStack {
            BrewTheme.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: BrewTheme.Spacing.lg) {
                    Spacer(minLength: BrewTheme.Spacing.xl)

                    VStack(spacing: BrewTheme.Spacing.xs) {
                        Text("Brew.")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .foregroundStyle(BrewTheme.Color.accent)
                        Text("Rate drinks. Find your taste.")
                            .font(BrewTheme.Font.callout)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }

                    VStack(spacing: BrewTheme.Spacing.md) {
                        Picker("", selection: $isSignUp) {
                            Text("Sign Up").tag(true)
                            Text("Sign In").tag(false)
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: BrewTheme.Spacing.sm) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .foregroundStyle(.black)
                                .padding(BrewTheme.Spacing.sm)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))

                            SecureField("Password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .foregroundStyle(.black)
                                .padding(BrewTheme.Spacing.sm)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))

                            if isSignUp && !password.isEmpty && password.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .font(BrewTheme.Font.caption)
                                    .foregroundStyle(BrewTheme.Color.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        BrewPrimaryButton(isSignUp ? "Create Account" : "Sign In", isDisabled: !canSubmit) {
                            Task {
                                isLoading = true
                                if isSignUp {
                                    await authService.signUpWithEmail(email: email, password: password)
                                } else {
                                    await authService.signInWithEmail(email: email, password: password)
                                }
                                isLoading = false
                            }
                        }

                        if let error = authService.error {
                            Text(error)
                                .font(BrewTheme.Font.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        if let resetMessage = authService.resetPasswordMessage {
                            Text(resetMessage)
                                .font(BrewTheme.Font.caption)
                                .foregroundStyle(BrewTheme.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        if !isSignUp {
                            Button {
                                resetEmail = email
                                showForgotPassword = true
                            } label: {
                                Text("Forgot password?")
                                    .font(BrewTheme.Font.caption)
                                    .foregroundStyle(BrewTheme.Color.accent)
                            }
                        }

                        Button {
                            authService.bypassForDemo()
                        } label: {
                            Text("Demo Mode")
                                .font(BrewTheme.Font.caption)
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                        }
                        .padding(.top, BrewTheme.Spacing.xs)
                    }
                    .padding(.horizontal, BrewTheme.Spacing.md)

                    Spacer(minLength: BrewTheme.Spacing.xl)
                }
            }
        }
        .alert("Reset password", isPresented: $showForgotPassword) {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) {}
            Button("Send reset link") {
                guard resetEmail.contains("@") else { return }
                Task { await authService.sendPasswordReset(email: resetEmail) }
            }
        } message: {
            Text("We'll email you a link to set a new password.")
        }
    }
}
