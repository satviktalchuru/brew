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

    enum Tab { case home, explore, friends, profile }

    var body: some View {
        VStack(spacing: 0) {
            // .page style makes the content itself swipeable left/right,
            // same as tapping the bar below — "Log" isn't a real screen
            // (it opens a sheet), so it's intentionally not one of the pages.
            TabView(selection: $selectedTab) {
                HomeView(store: store)
                    .tag(Tab.home)

                ExploreView(store: store)
                    .tag(Tab.explore)

                FriendsView(store: store)
                    .tag(Tab.friends)
                    .onAppear { notificationService.clearBadge() }

                ProfileView(store: store, authService: authService)
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            BrewTabBar(
                selectedTab: $selectedTab,
                pendingFriendsCount: pendingFriendsCount,
                onTapLog: { showLogSheet = true }
            )
        }
        .tint(BrewTheme.Color.accent)
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

// MARK: - Custom Tab Bar

// Stands in for the system tab bar since .page-style TabView doesn't render
// one. "Log" sits in the middle as a tap-only action (never highlighted as
// selected — it doesn't correspond to a swipeable page).
private struct BrewTabBar: View {
    @Binding var selectedTab: RootView.Tab
    var pendingFriendsCount: Int
    var onTapLog: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, label: "Home", systemImage: "house.fill")
            tabButton(.explore, label: "Explore", systemImage: "mappin.circle.fill")
            logButton
            tabButton(.friends, label: "Friends", systemImage: "person.2.fill", badge: pendingFriendsCount)
            tabButton(.profile, label: "Profile", systemImage: "person.crop.circle.fill")
        }
        .padding(.top, BrewTheme.Spacing.xs)
        .padding(.bottom, BrewTheme.Spacing.xxs)
        .background(.bar)
    }

    private func tabButton(_ tab: RootView.Tab, label: String, systemImage: String, badge: Int = 0) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 21))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.red))
                            .offset(x: 10, y: -8)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? BrewTheme.Color.accent : BrewTheme.Color.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button(action: onTapLog) {
            VStack(spacing: 2) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 21))
                Text("Log")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(BrewTheme.Color.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
