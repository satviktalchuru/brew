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
    @State private var showAddFriends = false

    enum Tab { case home, explore, friends, profile }

    @State private var tabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // .page style makes the content itself swipeable left/right,
            // same as tapping the bar below — "Log" isn't a real screen
            // (it opens a sheet), so it's intentionally not one of the pages.
            TabView(selection: $selectedTab) {
                HomeView(
                    store: store,
                    onLogDrink: { showLogSheet = true },
                    onAddFriends: { goToAddFriends() },
                    onCompare: { startCompare() }
                )
                .tag(Tab.home)

                ExploreView(store: store, tabBarHidden: $tabBarHidden)
                    .tag(Tab.explore)

                FriendsView(store: store, showAddFriends: $showAddFriends)
                    .tag(Tab.friends)
                    .onAppear { notificationService.clearBadge() }

                ProfileView(store: store, authService: authService)
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Reserve scrollable space so list bottoms can clear the floating bar.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !tabBarHidden {
                    SwiftUI.Color.clear.frame(height: 58)
                }
            }

            if !tabBarHidden {
                BrewTabBar(
                    selectedTab: $selectedTab,
                    pendingFriendsCount: pendingFriendsCount,
                    onTapLog: { showLogSheet = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: tabBarHidden)
        .background(BrewTheme.Color.background.ignoresSafeArea())
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

    // Switch to the Friends tab, then open its Add Friends sheet. The short
    // delay lets the tab transition finish so the sheet reliably presents
    // from the now-visible page.
    private func goToAddFriends() {
        withAnimation { selectedTab = .friends }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showAddFriends = true
        }
    }

    private func startCompare() {
        let pairs = store.candidateComparisonPairs()
        if !pairs.isEmpty {
            pendingPairs = pairs
            showHeadToHead = true
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
        .padding(.horizontal, BrewTheme.Spacing.xs)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(BrewTheme.Color.border.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: BrewTheme.Color.roastDark.opacity(0.18), radius: 14, x: 0, y: 6)
        .padding(.horizontal, BrewTheme.Spacing.md)
        .padding(.bottom, BrewTheme.Spacing.xxs)
    }

    private func tabButton(_ tab: RootView.Tab, label: String, systemImage: String, badge: Int = 0) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 40)
                    .background {
                        if isSelected {
                            Capsule().fill(BrewTheme.Color.accentLight)
                        }
                    }
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(.red))
                        .offset(x: 6, y: -4)
                }
            }
            .foregroundStyle(isSelected ? BrewTheme.Color.accent : BrewTheme.Color.textTertiary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(label)
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button(action: onTapLog) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(BrewTheme.Color.accent))
                .shadow(color: BrewTheme.Color.accent.opacity(0.35), radius: 6, y: 3)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Log a drink")
        }
        .buttonStyle(.plain)
    }
}
