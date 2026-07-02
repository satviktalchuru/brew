import SwiftUI

struct RootView: View {
    var store: AppStore
    var authService: AuthService
    var notificationService: NotificationService
    @State private var selectedTab: Tab = .home
    @State private var showLogSheet = false
    @State private var showHeadToHead = false
    @State private var pendingPairs: [(DrinkLog, DrinkLog)] = []
    @State private var rankingLog: DrinkLog? = nil
    @State private var deepLinkShop: Shop? = nil
    @State private var deepLinkLog: DrinkLog? = nil

    enum Tab { case home, explore, log, friends, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(store: store)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            ExploreView(store: store)
                .tabItem { Label("Explore", systemImage: "mappin.circle.fill") }
                .tag(Tab.explore)

            Color.clear
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(Tab.log)

            FriendsView(store: store)
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(Tab.friends)
                .badge(pendingFriendsCount)

            ProfileView(store: store, authService: authService)
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(BrewTheme.Color.accent)
        .onChange(of: selectedTab) { _, new in
            if new == .log {
                showLogSheet = true
                selectedTab = .home
            }
            if new == .friends {
                notificationService.clearBadge()
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogView(store: store) { newLog in
                if let newLog { rankingLog = newLog }
            }
        }
        .sheet(item: $rankingLog) { log in
            RankPlacementView(store: store, newLog: log) { wantsMore in
                rankingLog = nil
                guard wantsMore else { return }
                let pairs = store.candidateComparisonPairs()
                if !pairs.isEmpty {
                    pendingPairs = pairs
                    showHeadToHead = true
                }
            }
        }
        .sheet(isPresented: $showHeadToHead) {
            HeadToHeadView(store: store, pairs: pendingPairs) {
                pendingPairs = []
            }
        }
        .sheet(item: $deepLinkShop) { shop in
            NavigationStack {
                ShopDetailView(store: store, shop: shop)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $deepLinkLog) { log in
            NavigationStack {
                DrinkDetailView(store: store, log: log)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onChange(of: store.pendingDeepLink) { _, link in
            guard let link else { return }
            switch link {
            case .shop(let id):
                deepLinkShop = store.shop(id: id)
            case .drink(let id):
                deepLinkLog = store.drinkLogs.first { $0.id == id }
            }
            store.pendingDeepLink = nil
        }
    }

    private var pendingFriendsCount: Int {
        let pendingChats = store.chatRequests.filter {
            $0.addresseeID == store.currentUserID && $0.status == .pending
        }.count
        let pendingFriendReqs = store.pendingInboundRequests.count
        return pendingChats + pendingFriendReqs
    }
}
