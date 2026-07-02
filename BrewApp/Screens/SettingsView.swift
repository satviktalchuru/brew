import SwiftUI

struct SettingsView: View {
    var authService: AuthService
    var store: AppStore

    @Environment(\.dismiss) private var dismiss

    @AppStorage("brew.isPublic") private var isPublic = true
    @AppStorage("brew.appearInChats") private var appearInChats = true
    @AppStorage("brew.quizSweetness") private var savedSweetness: Int = 3
    @AppStorage("brew.quizStrength") private var savedStrength: Int = 3
    @AppStorage("brew.quizRoast") private var savedRoast: String = "medium"

    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var showBlockedUsers = false

    // Apple Guideline 1.2 requires published developer contact info for
    // reporting concerns. Replace with your real support address/URL.
    private let supportEmail = "satvik.talchuru@gmail.com"
    private let privacyPolicyURL = URL(string: "https://satviktalchuru.github.io/brew/privacy.html")!

    var body: some View {
        NavigationStack {
            List {
                Section("Recommendations") {
                    Stepper(value: $savedSweetness, in: 1...5) {
                        LabeledContent("Sweetness", value: "\(savedSweetness)/5")
                    }
                    Stepper(value: $savedStrength, in: 1...5) {
                        LabeledContent("Strength", value: "\(savedStrength)/5")
                    }
                    Picker("Roast", selection: $savedRoast) {
                        Text("Light").tag("light")
                        Text("Medium").tag("medium")
                        Text("Dark").tag("dark")
                    }
                }

                Section("Privacy") {
                    Toggle("Public Profile", isOn: $isPublic)
                    Toggle("Appear in Coffee Chats", isOn: $appearInChats)
                    Button {
                        showBlockedUsers = true
                    } label: {
                        LabeledContent("Blocked Users", value: store.blockedUserIDs.isEmpty ? "" : "\(store.blockedUserIDs.count)")
                    }
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                }

                Section("Account") {
                    if let session = authService.currentSession {
                        LabeledContent("User ID", value: String(session.userID.prefix(8)) + "…")
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                    }

                    Button(role: .destructive) {
                        authService.signOut()
                        dismiss()
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }

                    if authService.currentSession != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeletingAccount {
                                HStack {
                                    ProgressView().controlSize(.small)
                                    Text("Deleting…")
                                }
                            } else {
                                Label("Delete Account", systemImage: "trash")
                            }
                        }
                        .disabled(isDeletingAccount)
                    }
                }

                Section("Support") {
                    Link(destination: URL(string: "mailto:\(supportEmail)")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Backend", value: backendStatus)
                    if store.isSyncConfigured {
                        LabeledContent("Sync") {
                            if store.isSyncing {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Syncing…").foregroundStyle(BrewTheme.Color.textTertiary)
                                }
                            } else if let err = store.syncError {
                                Text(err)
                                    .font(BrewTheme.Font.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Label("Up to date", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(BrewTheme.Color.success)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete your account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Permanently", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        let success = await authService.deleteAccount()
                        isDeletingAccount = false
                        if success { dismiss() }
                    }
                }
            } message: {
                Text("This permanently deletes your account and all your drink logs, friends, and data. This can't be undone.")
            }
            .sheet(isPresented: $showBlockedUsers) {
                BlockedUsersView(store: store)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var backendStatus: String {
        let url = SupabaseConfig.projectURL
        return url.contains("YOUR_PROJECT") ? "Demo (not connected)" : "Supabase"
    }
}

// MARK: - Blocked Users

private struct BlockedUsersView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var blocked: [BrewUser] {
        store.blockedUserIDs.compactMap { store.user(id: $0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if blocked.isEmpty {
                    ContentUnavailableView("No blocked users", systemImage: "hand.raised.slash")
                } else {
                    List(blocked) { user in
                        HStack {
                            AvatarView(user: user, size: 36)
                            Text(user.displayName)
                                .foregroundStyle(BrewTheme.Color.textPrimary)
                            Spacer()
                            Button("Unblock") {
                                store.unblockUser(user.id)
                            }
                            .font(BrewTheme.Font.captionSemibold)
                        }
                    }
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
