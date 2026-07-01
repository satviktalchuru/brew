import SwiftUI

struct SettingsView: View {
    var authService: AuthService
    var store: AppStore

    @Environment(\.dismiss) private var dismiss

    @AppStorage("brew.isPublic") private var isPublic = true
    @AppStorage("brew.appearInChats") private var appearInChats = true

    var body: some View {
        NavigationStack {
            List {
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
