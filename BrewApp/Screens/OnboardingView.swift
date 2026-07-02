import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    var authService: AuthService
    var store: AppStore
    var onAuthComplete: () -> Void = {}

    @State private var page: Page = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false

    enum Page { case welcome, emailAuth }

    var body: some View {
        switch page {
        case .welcome:
            welcomePage
        case .emailAuth:
            emailAuthPage
        }
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        ZStack {
            BrewTheme.Color.background.ignoresSafeArea()

            VStack(spacing: BrewTheme.Spacing.lg) {
                Spacer()

                VStack(spacing: BrewTheme.Spacing.xs) {
                    Text("Brew")
                        .font(.system(size: 56, weight: .bold, design: .serif))
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Text("Rate drinks. Find your taste.")
                        .font(BrewTheme.Font.callout)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }

                Spacer()

                VStack(spacing: BrewTheme.Spacing.sm) {
                    Button {
                        authService.signInWithGoogle()
                    } label: {
                        HStack(spacing: BrewTheme.Spacing.xs) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                                .foregroundStyle(BrewTheme.Color.accent)
                            Text("Continue with Google")
                                .font(BrewTheme.Font.bodySemibold)
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: BrewTheme.Radius.medium)
                                .stroke(BrewTheme.Color.border, lineWidth: 1)
                        }
                    }

                    Button {
                        page = .emailAuth
                    } label: {
                        Text("Continue with Email")
                            .font(BrewTheme.Font.bodySemibold)
                            .foregroundStyle(BrewTheme.Color.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay {
                                RoundedRectangle(cornerRadius: BrewTheme.Radius.medium)
                                    .stroke(BrewTheme.Color.accent, lineWidth: 1.5)
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
                .padding(.bottom, BrewTheme.Spacing.xl)

                if let error = authService.error {
                    Text(error)
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BrewTheme.Spacing.md)
                }
            }
        }
    }

    // MARK: - Email Auth

    private var emailAuthPage: some View {
        NavigationStack {
            ZStack {
                BrewTheme.Color.background.ignoresSafeArea()

                VStack(spacing: BrewTheme.Spacing.md) {
                    Picker("", selection: $isSignUp) {
                        Text("Sign In").tag(false)
                        Text("Sign Up").tag(true)
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
                    }

                    BrewPrimaryButton(isSignUp ? "Create Account" : "Sign In", isDisabled: isLoading) {
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

                    Spacer()
                }
                .padding(BrewTheme.Spacing.md)
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { page = .welcome }
                }
            }
        }
    }
}
