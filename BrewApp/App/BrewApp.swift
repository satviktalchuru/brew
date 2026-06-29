import SwiftUI

@main
struct BrewApp: App {
    @State private var store = AppStore.seeded()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
