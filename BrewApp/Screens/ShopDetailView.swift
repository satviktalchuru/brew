import SwiftUI

struct ShopDetailView: View {
    var store: AppStore
    var shop: Shop

    private var friendIDs: Set<UUID> {
        let ids = store.friendships
            .filter { $0.status == .accepted }
            .flatMap { [$0.requesterID, $0.addresseeID] }
        return Set(ids).subtracting([store.currentUserID])
    }

    private var shopLogs: [DrinkLog] {
        store.drinkLogs
            .filter { $0.shopID == shop.id }
            .sorted { $0.eloScore > $1.eloScore }
    }

    private var friendLogs: [DrinkLog] {
        shopLogs.filter { friendIDs.contains($0.userID) }
    }

    private var topDrinks: [DrinkLog] {
        var seen = Set<String>()
        return shopLogs.filter { seen.insert($0.drinkName.lowercased()).inserted }.prefix(3).map { $0 }
    }

    private var chatUsers: [BrewUser] {
        let visitorIDs = Set(shopLogs.map(\.userID))
            .subtracting([store.currentUserID])
            .subtracting(friendIDs)
        return visitorIDs.compactMap { store.user(id: $0) }.filter(\.appearInChats)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.md) {
                peekStrip
                shopHeader
                if !topDrinks.isEmpty { whatToOrderSection }
                if !friendLogs.isEmpty { friendsHereSection }
                if !chatUsers.isEmpty { coffeeChatSection }
                allDrinksSection
            }
            .padding(.bottom, BrewTheme.Spacing.xl)
        }
        .navigationTitle(shop.name)
        .navigationBarTitleDisplayMode(.inline)
        .brewScreenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if store.isOnWishlist(shopID: shop.id) {
                        for item in store.myWishlist where item.shopID == shop.id {
                            store.removeWishlistItem(id: item.id)
                        }
                    } else {
                        store.addWishlistItem(title: shop.name, shopID: shop.id)
                    }
                } label: {
                    Image(systemName: store.isOnWishlist(shopID: shop.id) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(BrewTheme.Color.accent)
                }
                .accessibilityLabel(store.isOnWishlist(shopID: shop.id) ? "Remove from wishlist" : "Add to wishlist")
            }
        }
        .navigationDestination(for: DrinkLog.self) { log in
            DrinkDetailView(store: store, log: log)
        }
        .navigationDestination(for: BrewUser.self) { user in
            FriendProfileView(store: store, user: user)
        }
    }

    // MARK: - Peek Strip (visible at smallest detent)

    private var peekStrip: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            Image(systemName: shop.heroSymbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [Color(hue: shop.accentHue, saturation: 0.6, brightness: 0.55), Color(hue: shop.accentHue, saturation: 0.5, brightness: 0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(BrewTheme.Font.title3)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: BrewTheme.Spacing.xs) {
                    Label(store.formattedDistance(to: shop), systemImage: "location.fill")
                    Text("·")
                    Text(shop.hours)
                }
                .font(BrewTheme.Font.caption)
                .foregroundStyle(BrewTheme.Color.textTertiary)
            }

            Spacer()

            let logCount = shopLogs.count
            if logCount > 0 {
                VStack(spacing: 1) {
                    Text("\(logCount)")
                        .font(BrewTheme.Font.title3)
                        .foregroundStyle(BrewTheme.Color.accent)
                    Text("logged")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
        .padding(.top, BrewTheme.Spacing.xs)
    }

    // MARK: - Shop Header

    private var shopHeader: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            Image(systemName: shop.heroSymbol)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hue: shop.accentHue, saturation: 0.6, brightness: 0.55),
                            Color(hue: shop.accentHue, saturation: 0.5, brightness: 0.30)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xxs) {
                Label(shop.address, systemImage: "mappin")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                Label(shop.hours, systemImage: "clock")
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
                Label(store.formattedDistance(to: shop), systemImage: "location.fill")
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
            }
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    // MARK: - What to Order

    private var whatToOrderSection: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            BrewSectionLabel("What to Order", subtitle: "Based on Brew ratings", systemImage: "star.fill")
                .padding(.horizontal, BrewTheme.Spacing.sm)

            ForEach(Array(topDrinks.enumerated()), id: \.element.id) { index, log in
                NavigationLink(value: log) {
                    TopDrinkRow(
                        rank: index + 1,
                        log: log,
                        totalLogs: shopLogs.filter { $0.drinkName.lowercased() == log.drinkName.lowercased() }.count
                    )
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Friends Here

    private var friendsHereSection: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            BrewSectionLabel("Friends Here", systemImage: "person.2.fill")
                .padding(.horizontal, BrewTheme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrewTheme.Spacing.sm) {
                    ForEach(friendLogs) { log in
                        if let user = store.user(id: log.userID) {
                            NavigationLink(value: user) {
                                FriendAtShopCard(user: user, log: log)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, BrewTheme.Spacing.sm)
            }
        }
    }

    // MARK: - Coffee Chats

    private var coffeeChatSection: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            BrewSectionLabel(
                "Coffee Chats",
                subtitle: "People who visit here",
                systemImage: "bubble.left.and.bubble.right.fill"
            )
            .padding(.horizontal, BrewTheme.Spacing.sm)

            ForEach(chatUsers) { user in
                ChatDiscoveryRow(store: store, user: user, shopID: shop.id)
                    .padding(.horizontal, BrewTheme.Spacing.sm)
            }
        }
    }

    // MARK: - All Drinks

    private var allDrinksSection: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            BrewSectionLabel("All Drinks Logged Here", systemImage: "list.bullet")
                .padding(.horizontal, BrewTheme.Spacing.sm)

            if shopLogs.isEmpty {
                Text("No drinks logged here yet. Be the first!")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
                    .padding(.horizontal, BrewTheme.Spacing.sm)
            } else {
                ForEach(shopLogs) { log in
                    NavigationLink(value: log) {
                        DrinkSummaryCard(
                            store: store,
                            log: log,
                            shop: shop,
                            user: store.user(id: log.userID),
                            showUser: true
                        )
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct TopDrinkRow: View {
    var rank: Int
    var log: DrinkLog
    var totalLogs: Int

    var body: some View {
        BrewCard {
            HStack(spacing: BrewTheme.Spacing.sm) {
                Text("\(rank)")
                    .font(BrewTheme.Font.title3)
                    .foregroundStyle(BrewTheme.Color.accent)
                    .monospacedDigit()
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: BrewTheme.Spacing.xxs) {
                    Text(log.drinkName)
                        .font(BrewTheme.Font.bodySemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    HStack(spacing: BrewTheme.Spacing.xs) {
                        BrewChip(title: log.roast.label, style: .roast(log.roast))
                        BrewChip(title: log.brewMethod.label)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(totalLogs)")
                        .font(BrewTheme.Font.bodySemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Text("logged")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                }
            }
        }
    }
}

private struct FriendAtShopCard: View {
    var user: BrewUser
    var log: DrinkLog

    var body: some View {
        BrewCard(padding: BrewTheme.Spacing.xs) {
            VStack(spacing: BrewTheme.Spacing.xs) {
                AvatarView(user: user, size: 44)
                Text(user.displayName.components(separatedBy: " ").first ?? user.displayName)
                    .font(BrewTheme.Font.captionSemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text(log.drinkName)
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 100)
        }
    }
}

private struct ChatDiscoveryRow: View {
    var store: AppStore
    var user: BrewUser
    var shopID: UUID

    private var alreadyRequested: Bool {
        store.chatRequests.contains {
            $0.requesterID == store.currentUserID &&
            $0.addresseeID == user.id &&
            $0.shopID == shopID &&
            ($0.status == .pending || $0.status == .accepted)
        }
    }

    var body: some View {
        BrewCard {
            HStack(spacing: BrewTheme.Spacing.sm) {
                AvatarView(user: user, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(BrewTheme.Font.bodySemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Text("@\(user.username)")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                }

                Spacer()

                let match = store.tasteMatchScore(with: user.id)
                if match > 0 {
                    VStack(spacing: 1) {
                        Text("\(match)%")
                            .font(BrewTheme.Font.bodySemibold)
                            .foregroundStyle(BrewTheme.Color.accent)
                        Text("match")
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                    }
                }

                Button {
                    store.sendChatRequest(to: user.id, at: shopID)
                } label: {
                    Text(alreadyRequested ? "Requested" : "Meet Here")
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(alreadyRequested ? BrewTheme.Color.textTertiary : .white)
                        .padding(.horizontal, BrewTheme.Spacing.xs)
                        .padding(.vertical, 6)
                        .background(alreadyRequested ? BrewTheme.Color.border : BrewTheme.Color.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(alreadyRequested)
            }
        }
    }
}
