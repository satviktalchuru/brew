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

    @State private var showLaunchAnimation = true

    var body: some Scene {
        WindowGroup {
            ZStack {
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

                if showLaunchAnimation {
                    LaunchMeltView {
                        showLaunchAnimation = false
                    }
                    .transition(.opacity)
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
                Task {
                    // Email confirmation links carry a session in the URL
                    // fragment (brew://confirmed#access_token=...) — try that
                    // first; only fall through to content deep links if this
                    // wasn't one.
                    let handled = await authService.handleEmailConfirmation(url: url)
                    if !handled {
                        store.pendingDeepLink = DeepLink(url: url)
                    }
                }
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
        store.tokenRefresher = { await authService.refreshAccessToken()?.accessToken }
        await store.configureSync(supabase: authService.supabase, session: session)
    }
}
