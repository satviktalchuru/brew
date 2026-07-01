import SwiftUI

struct HomeView: View {
    var store: AppStore
    @State private var showActivity = false

    private var activityCount: Int { store.activityEvents.count }

    var body: some View {
        NavigationStack {
            Group {
                if !feedLogs.isEmpty {
                    feedList
                } else if friendIDs.isEmpty {
                    brandedHome
                } else {
                    emptyState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .brewScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("brew.")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundStyle(BrewTheme.Color.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showActivity = true } label: {
                        Image(systemName: activityCount > 0 ? "bell.badge.fill" : "bell")
                            .foregroundStyle(activityCount > 0 ? BrewTheme.Color.accent : BrewTheme.Color.textSecondary)
                    }
                    .accessibilityLabel("Activity, \(activityCount) new")
                }
            }
            .sheet(isPresented: $showActivity) {
                ActivityFeedView(store: store)
            }
        }
    }

    // MARK: - Feed

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: BrewTheme.Spacing.sm) {
                ForEach(groupedFeed, id: \.0) { section, logs in
                    Section {
                        ForEach(logs) { log in
                            NavigationLink(value: log) {
                                DrinkSummaryCard(
                                    log: log,
                                    shop: log.shopID.flatMap { store.shop(id: $0) },
                                    user: store.user(id: log.userID),
                                    showUser: true
                                )
                                .padding(.horizontal, BrewTheme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(section)
                                .font(BrewTheme.Font.caption)
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                        .padding(.top, BrewTheme.Spacing.xs)
                    }
                }
            }
            .padding(.vertical, BrewTheme.Spacing.sm)
        }
        .refreshable {
            await store.refreshFeed()
        }
        .navigationDestination(for: DrinkLog.self) { log in
            DrinkDetailView(store: store, log: log)
        }
        .navigationDestination(for: Shop.self) { shop in
            ShopDetailView(store: store, shop: shop)
        }
    }

    // MARK: - Empty State (has friends, nothing logged yet)

    private var emptyState: some View {
        VStack(spacing: BrewTheme.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundStyle(BrewTheme.Color.textTertiary)
            Text("Nothing logged yet")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
            Text("Your friends haven't logged any drinks yet.\nCheck back soon!")
                .font(BrewTheme.Font.callout)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Branded Home (no friends yet)

    private var trendingLogs: [DrinkLog] { store.trendingDrinks(limit: 8) }

    private var brandedHome: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: BrewTheme.Spacing.sm) {
                    Text("brew.")
                        .font(.system(size: 72, weight: .black, design: .serif))
                        .foregroundStyle(BrewTheme.Color.accent)
                    Text("Your coffee, ranked.")
                        .font(BrewTheme.Font.title3)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, BrewTheme.Spacing.xl)
                .padding(.bottom, BrewTheme.Spacing.xl)

                VStack(spacing: BrewTheme.Spacing.sm) {
                    HStack(spacing: BrewTheme.Spacing.sm) {
                        ctaCard(icon: "plus.circle.fill", title: "Log a Drink",
                                detail: "Start building\nyour taste profile", accent: true)
                        ctaCard(icon: "person.badge.plus.fill", title: "Add Friends",
                                detail: "See what they're\nordering", accent: false)
                    }
                    .padding(.horizontal, BrewTheme.Spacing.sm)

                    BrewCard {
                        HStack(spacing: BrewTheme.Spacing.sm) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.title3)
                                .foregroundStyle(BrewTheme.Color.accent)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Compare to rank")
                                    .font(BrewTheme.Font.bodySemibold)
                                    .foregroundStyle(BrewTheme.Color.textPrimary)
                                Text("Head-to-head picks build your ELO-ranked list automatically")
                                    .font(BrewTheme.Font.caption)
                                    .foregroundStyle(BrewTheme.Color.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                }
                .padding(.bottom, BrewTheme.Spacing.xl)

                if !trendingLogs.isEmpty {
                    VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                        BrewSectionLabel("Trending on Brew", systemImage: "flame.fill")
                            .padding(.horizontal, BrewTheme.Spacing.sm)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: BrewTheme.Spacing.sm) {
                                ForEach(trendingLogs) { log in
                                    NavigationLink(value: log) { trendingPill(log) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, BrewTheme.Spacing.sm)
                        }
                    }
                    .padding(.bottom, BrewTheme.Spacing.xl)
                }
            }
        }
        .navigationDestination(for: DrinkLog.self) { log in DrinkDetailView(store: store, log: log) }
    }

    private func ctaCard(icon: String, title: String, detail: String, accent: Bool) -> some View {
        BrewCard {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(accent ? .white : BrewTheme.Color.accent)
                    .frame(width: 44, height: 44)
                    .background(accent ? BrewTheme.Color.accent : BrewTheme.Color.accentLight)
                    .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small, style: .continuous))
                Text(title)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text(detail)
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func trendingPill(_ log: DrinkLog) -> some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xxs) {
            Text(log.drinkName)
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(BrewTheme.Color.textPrimary)
                .lineLimit(1)
            BrewChip(title: log.roast.label, style: .roast(log.roast))
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
        .padding(.vertical, BrewTheme.Spacing.xs)
        .background(BrewTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                .stroke(BrewTheme.Color.border.opacity(0.7), lineWidth: 1)
        }
    }

    // MARK: - Helpers

    private var friendIDs: Set<UUID> {
        let ids = store.friendships
            .filter { $0.status == .accepted }
            .flatMap { [$0.requesterID, $0.addresseeID] }
        return Set(ids).subtracting([store.currentUserID])
    }

    private var feedLogs: [DrinkLog] {
        store.drinkLogs
            .filter { friendIDs.contains($0.userID) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private var groupedFeed: [(String, [DrinkLog])] {
        let now = Date.now
        let todayStart = Calendar.current.startOfDay(for: now)
        let weekStart = now.addingTimeInterval(-7 * 24 * 3600)

        var today: [DrinkLog] = []
        var thisWeek: [DrinkLog] = []
        var earlier: [DrinkLog] = []

        for log in feedLogs {
            if log.loggedAt >= todayStart {
                today.append(log)
            } else if log.loggedAt >= weekStart {
                thisWeek.append(log)
            } else {
                earlier.append(log)
            }
        }

        return [("Today", today), ("This Week", thisWeek), ("Earlier", earlier)]
            .filter { !$0.1.isEmpty }
    }
}
