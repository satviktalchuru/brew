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
