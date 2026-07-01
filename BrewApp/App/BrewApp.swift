import SwiftUI

@main
struct BrewApp: App {
    @State private var store = AppStore.seeded()
    @State private var authService = AuthService()
    @State private var notificationService = NotificationService()
    @State private var locationService = LocationService()

    @AppStorage("brew.quizCompleted") private var quizCompleted = false
    @AppStorage("brew.quizTaken")     private var quizTaken     = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !authService.isAuthenticated {
                    OnboardingView(authService: authService, store: store, onAuthComplete: {
                        // After auth, quiz flow begins
                    })
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
            }
            .onOpenURL { url in
                store.pendingDeepLink = DeepLink(url: url)
            }
        }
    }
}
