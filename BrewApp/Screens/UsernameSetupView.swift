import SwiftUI

// Shown once after a real sign-up so the user can claim a handle.
// The signup trigger seeds username from the email local-part; this lets
// them personalize it before entering the app.
struct UsernameSetupView: View {
    var store: AppStore
    var onComplete: () -> Void

    @State private var username = ""
    @State private var displayName = ""
    @State private var isSaving = false

    private var cleanedUsername: String {
        username.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var isValid: Bool {
        let u = cleanedUsername
        guard u.count >= 3, u.count <= 20 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        return u.unicodeScalars.allSatisfy { allowed.contains($0) }
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            BrewTheme.Color.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: BrewTheme.Spacing.lg) {
                Spacer(minLength: BrewTheme.Spacing.xl)

                VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                    Text("Claim your handle")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Text("This is how friends will find you on Brew.")
                        .font(BrewTheme.Font.callout)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: BrewTheme.Spacing.md) {
                    fieldGroup(label: "Display name") {
                        TextField("Jamie Rivera", text: $displayName)
                            .textContentType(.name)
                            .foregroundStyle(.black)
                            .padding(BrewTheme.Spacing.sm)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))
                    }

                    fieldGroup(label: "Username") {
                        HStack(spacing: 2) {
                            Text("@")
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                            TextField("jamie", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(.black)
                        }
                        .padding(BrewTheme.Spacing.sm)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))

                        Text("3–20 characters · letters, numbers, underscores")
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                    }
                }

                Spacer()

                BrewPrimaryButton("Continue", isDisabled: !isValid || isSaving) {
                    isSaving = true
                    store.updateUsername(cleanedUsername, displayName: displayName.trimmingCharacters(in: .whitespaces))
                    onComplete()
                }
            }
            .padding(BrewTheme.Spacing.md)
        }
        .onAppear {
            // Prefill from whatever the trigger already set.
            if let me = store.user(id: store.currentUserID) {
                if username.isEmpty { username = me.username }
                if displayName.isEmpty { displayName = me.displayName }
            }
        }
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Text(label)
                .font(BrewTheme.Font.footnote)
                .foregroundStyle(BrewTheme.Color.textSecondary)
            content()
        }
    }
}
