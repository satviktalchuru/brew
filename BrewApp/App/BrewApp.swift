import SwiftUI

@main
struct BrewApp: App {
    @State private var store = AppStore.seeded()
    @State private var authService = AuthService()
    @State private var notificationService = NotificationService()
    @State private var locationService = LocationService()

    @AppStorage("brew.quizCompleted") private var quizCompleted = false
    @AppStorage("brew.quizTaken")     private var quizTaken     = false
    @AppStorage("brew.usernameSet")   private var usernameSet   = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !authService.isAuthenticated {
                    OnboardingView(authService: authService, store: store, onAuthComplete: {})
                } else if needsUsername {
                    UsernameSetupView(store: store) {
                        usernameSet = true
                    }
                } else if !quizTaken {
                    TasteQuizView(store: store) {
                        quizTaken = true
                    }
                } else if !quizCompleted {
                    FirstPicksView(store: store, locationService: locationService) {
                        quizCompleted = true
                    }
                } else {
                    RootView(store: store, authService: authService, notificationService: notificationService)
                }
            }
            .task {
                await notificationService.requestAuthorization()
                store.notificationService = notificationService
                store.locationService = locationService
                locationService.requestAuthorization()
                // Restore a real session for returning users (refresh-token exchange).
                await authService.restoreSession()
                await configureSyncIfPossible()
            }
            .onChange(of: authService.currentSession?.accessToken) { _, _ in
                Task { await configureSyncIfPossible() }
            }
            .onChange(of: authService.isAuthenticated) { _, isAuth in
                if !isAuth { store.teardownSync() }
            }
            .onOpenURL { url in
                store.pendingDeepLink = DeepLink(url: url)
            }
            .preferredColorScheme(.light)
        }
    }

    // Real (Supabase) sessions must set a username; demo/no-session mode skips it.
    private var needsUsername: Bool {
        authService.currentSession != nil && !usernameSet
    }

    private func configureSyncIfPossible() async {
        guard let session = authService.currentSession else { return }
        await store.configureSync(supabase: authService.supabase, session: session)
    }
}
