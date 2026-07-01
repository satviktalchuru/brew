import SwiftUI

struct FriendProfileView: View {
    var store: AppStore
    var user: BrewUser

    private var profile: TasteProfile { store.tasteProfile(for: user.id) }

    private var userLogs: [DrinkLog] {
        store.drinkLogs
            .filter { $0.userID == user.id }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    private var topFive: [DrinkLog] {
        store.drinkLogs
            .filter { $0.userID == user.id }
            .sorted { $0.eloScore > $1.eloScore }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.md) {
                profileHeader
                tasteCard
                topDrinksSection
                recentSection
            }
            .padding(.bottom, BrewTheme.Spacing.xl)
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.large)
        .brewScreenBackground()
        .navigationDestination(for: DrinkLog.self) { log in
            DrinkDetailView(store: store, log: log)
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            AvatarView(user: user, size: 80)

            VStack(spacing: 2) {
                Text(user.displayName)
                    .font(BrewTheme.Font.title2)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text("@\(user.username)")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            }

            HStack(spacing: BrewTheme.Spacing.lg) {
                statPill(value: userLogs.count, label: "Drinks")
                statPill(
                    value: Set(userLogs.filter { !$0.isHomeBrew }.compactMap(\.shopID)).count,
                    label: "Shops"
                )
            }

            let match = store.tasteMatchScore(with: user.id)
            if match > 0 {
                BrewChip(title: "\(match)% taste match", systemImage: "sparkles")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
            Text(label)
                .font(BrewTheme.Font.caption)
                .foregroundStyle(BrewTheme.Color.textTertiary)
        }
    }

    // MARK: - Taste Card

    private var tasteCard: some View {
        BrewCard {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                HStack {
                    Text("Their Taste Profile")
                        .font(BrewTheme.Font.title3)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Spacer()
                    BrewChip(title: profile.identityLabel, systemImage: "sparkles")
                }
                Divider()
                DotRating(value: Int(profile.averageSweetness.rounded()), label: "Sweetness")
                DotRating(value: Int(profile.averageStrength.rounded()), label: "Strength")
                if !profile.topFlavorDescriptors.isEmpty {
                    Divider()
                    HStack(spacing: BrewTheme.Spacing.xs) {
                        ForEach(profile.topFlavorDescriptors.prefix(3), id: \.self) { flavor in
                            BrewChip(title: flavor, style: .neutral)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    // MARK: - Top Drinks

    @ViewBuilder
    private var topDrinksSection: some View {
        if !topFive.isEmpty {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                BrewSectionLabel("Their Top Drinks", systemImage: "list.number")
                    .padding(.horizontal, BrewTheme.Spacing.sm)

                ForEach(Array(topFive.enumerated()), id: \.element.id) { index, log in
                    NavigationLink(value: log) {
                        RankedDrinkRow(
                            rank: index + 1,
                            log: log,
                            shop: log.shopID.flatMap { store.shop(id: $0) }
                        )
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recent Activity

    @ViewBuilder
    private var recentSection: some View {
        if !userLogs.isEmpty {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                BrewSectionLabel("Recent Check-ins", systemImage: "clock")
                    .padding(.horizontal, BrewTheme.Spacing.sm)

                ForEach(userLogs.prefix(5)) { log in
                    NavigationLink(value: log) {
                        DrinkSummaryCard(
                            log: log,
                            shop: log.shopID.flatMap { store.shop(id: $0) },
                            user: user,
                            showUser: false
                        )
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
