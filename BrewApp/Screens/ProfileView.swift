import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    var store: AppStore
    var authService: AuthService
    @State private var rankingTab: RankingTab = .shopDrinks
    @State private var showSettings = false
    @State private var showRecap = false
    @State private var showComparisons = false
    @State private var showExport = false
    @State private var showWishlist = false
    @State private var avatarPickerItem: PhotosPickerItem? = nil

    enum RankingTab: String, CaseIterable {
        case shopDrinks = "Shop Drinks"
        case homeBrews = "Home Brews"
    }

    private var currentUser: BrewUser? { store.user(id: store.currentUserID) }
    private var profile: TasteProfile { store.tasteProfile(for: store.currentUserID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrewTheme.Spacing.md) {
                    BrewPageTitle(currentUser?.displayName ?? "Profile")
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                    profileHeader
                    tasteProfileCard
                    wishlistCard
                    rankingsSection
                }
                .padding(.vertical, BrewTheme.Spacing.sm)
            }
            .navigationTitle(currentUser?.displayName ?? "Profile")
            // Inline: large titles clip inside the paged root TabView; the
            // serif header above renders the name instead.
            .navigationBarTitleDisplayMode(.inline)
            .brewScreenBackground()
            .navigationDestination(for: DrinkLog.self) { log in
                DrinkDetailView(store: store, log: log)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: BrewTheme.Spacing.sm) {
                        Button { showComparisons = true } label: {
                            Image(systemName: "arrow.left.arrow.right")
                        }
                        .accessibilityLabel("Comparison history")
                        Button { showRecap = true } label: {
                            Image(systemName: "chart.bar.fill")
                        }
                        ShareLink(
                            item: renderedRankingsCard(),
                            preview: SharePreview("My Brew Rankings", image: renderedRankingsCard())
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export rankings")
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authService: authService, store: store)
            }
            .sheet(isPresented: $showRecap) {
                TasteRecapView(store: store)
            }
            .sheet(isPresented: $showComparisons) {
                ComparisonHistoryView(store: store)
            }
            .sheet(isPresented: $showWishlist) {
                WishlistView(store: store)
            }
        }
    }

    // MARK: - Wishlist entry

    private var wishlistCard: some View {
        Button { showWishlist = true } label: {
            BrewCard {
                HStack(spacing: BrewTheme.Spacing.sm) {
                    Image(systemName: "bookmark.fill")
                        .font(.title3)
                        .foregroundStyle(BrewTheme.Color.accent)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Want to Try")
                            .font(BrewTheme.Font.bodySemibold)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                        Text(store.myWishlist.isEmpty ? "Save coffees & shops for later" : "\(store.myWishlist.count) saved")
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                }
            }
            .padding(.horizontal, BrewTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            if let user = currentUser {
                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(user: user, size: 80, image: store.avatarImage(for: user.id))
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(BrewTheme.Color.accent)
                            .background(Circle().fill(BrewTheme.Color.surface).padding(2))
                    }
                }
                .onChange(of: avatarPickerItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            store.setAvatar(data: data)
                        }
                    }
                }
                Text("@\(user.username)")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)

                if store.logStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("\(store.logStreak) day streak")
                            .font(BrewTheme.Font.captionSemibold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            HStack(spacing: BrewTheme.Spacing.lg) {
                statPill(
                    value: store.drinkLogs.filter { $0.userID == store.currentUserID }.count,
                    label: "Drinks"
                )
                statPill(
                    value: Set(
                        store.drinkLogs
                            .filter { $0.userID == store.currentUserID && !$0.isHomeBrew }
                            .compactMap(\.shopID)
                    ).count,
                    label: "Shops"
                )
                statPill(
                    value: store.friendships.filter {
                        $0.status == .accepted &&
                        ($0.requesterID == store.currentUserID || $0.addresseeID == store.currentUserID)
                    }.count,
                    label: "Friends"
                )
            }
        }
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

    // MARK: - Taste Profile Card

    private var tasteProfileCard: some View {
        BrewCard {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                HStack {
                    Text("Your Coffee Identity")
                        .font(BrewTheme.Font.title3)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Spacer()
                    BrewChip(title: profile.identityLabel, systemImage: "sparkles")
                    ShareLink(
                        item: renderedTasteCard(),
                        preview: SharePreview("My Coffee Identity", image: renderedTasteCard())
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.callout)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }
                }

                Divider()

                HStack(spacing: BrewTheme.Spacing.md) {
                    roastBreakdown
                    Divider().frame(height: 60)
                    VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                        DotRating(value: Int(profile.averageSweetness.rounded()), label: "Sweet")
                        DotRating(value: Int(profile.averageStrength.rounded()), label: "Strong")
                    }
                }

                if !profile.topFlavorDescriptors.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                        Text("Top Flavors")
                            .font(BrewTheme.Font.captionSemibold)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                            .textCase(.uppercase)
                        HStack(spacing: BrewTheme.Spacing.xs) {
                            ForEach(profile.topFlavorDescriptors.prefix(4), id: \.self) { flavor in
                                flavorChip(flavor)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    // Profile-only treatment: each top flavor is tinted to match its word
    // (blackberry = deep purple, caramel = golden brown, ...). Other screens
    // intentionally keep the neutral chip style.
    private func flavorChip(_ flavor: String) -> some View {
        let tint = FlavorPalette.color(for: flavor)
        return Text(flavor)
            .font(BrewTheme.Font.captionSemibold)
            .foregroundStyle(tint)
            .padding(.horizontal, BrewTheme.Spacing.xs)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.35), lineWidth: 1)
            }
    }

    private var roastBreakdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roast")
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .textCase(.uppercase)
            ForEach([Roast.light, .medium, .dark], id: \.self) { roast in
                let count = profile.roastCounts[roast] ?? 0
                HStack(spacing: BrewTheme.Spacing.xs) {
                    Circle()
                        .fill(BrewTheme.Color.roast(roast))
                        .frame(width: 8, height: 8)
                    Text("\(roast.label): \(count)")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Rankings

    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
            Picker("Rankings", selection: $rankingTab) {
                ForEach(RankingTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, BrewTheme.Spacing.sm)

            let ranked = store.rankedDrinks(includeHomeBrews: true)
                .filter { rankingTab == .homeBrews ? $0.isHomeBrew : !$0.isHomeBrew }

            if ranked.isEmpty {
                emptyRankings
            } else {
                LazyVStack(spacing: BrewTheme.Spacing.xs) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, log in
                        NavigationLink(value: log) {
                            RankedDrinkRow(
                                rank: index + 1,
                                log: log,
                                shop: log.shopID.flatMap { store.shop(id: $0) }
                            )
                            .padding(.horizontal, BrewTheme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.deleteDrinkLog(id: log.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyRankings: some View {
        VStack(spacing: 0) {
            // Hero
            ZStack {
                Circle()
                    .fill(BrewTheme.Color.accentLight)
                    .frame(width: 96, height: 96)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(BrewTheme.Color.accent)
            }
            .padding(.bottom, BrewTheme.Spacing.md)

            Text("Your rankings start here")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
                .padding(.bottom, BrewTheme.Spacing.xs)

            Text("Log your first drink, then do a head-to-head comparison — your personal ranked list builds itself from there.")
                .font(BrewTheme.Font.callout)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, BrewTheme.Spacing.lg)

            // Steps
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                firstLogStep(number: "1", icon: "plus.circle.fill", label: "Tap Log", detail: "Add a drink from any coffee shop")
                firstLogStep(number: "2", icon: "arrow.left.arrow.right", label: "Compare", detail: "Pick your favourite in head-to-head")
                firstLogStep(number: "3", icon: "list.number", label: "Watch it rank", detail: "ELO scores build your personal top list")
            }
            .padding(BrewTheme.Spacing.md)
            .background(BrewTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.large, style: .continuous))
            .padding(.bottom, BrewTheme.Spacing.md)

            Text("The more you log, the smarter your taste profile gets.")
                .font(BrewTheme.Font.caption)
                .foregroundStyle(BrewTheme.Color.textTertiary)
                .multilineTextAlignment(.center)
                .italic()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BrewTheme.Spacing.md)
        .padding(.vertical, BrewTheme.Spacing.lg)
    }

    @MainActor
    private func renderedTasteCard() -> Image {
        let renderer = ImageRenderer(content: TasteShareCardView(profile: profile, user: currentUser))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage { return Image(uiImage: uiImage) }
        return Image(systemName: "person.crop.square")
    }

    @MainActor
    private func renderedRankingsCard() -> Image {
        let top = store.rankedDrinks(includeHomeBrews: false).prefix(10).map { $0 }
        let renderer = ImageRenderer(content: RankingsShareCardView(logs: top, user: currentUser))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage { return Image(uiImage: uiImage) }
        return Image(systemName: "list.number")
    }

    private func firstLogStep(number: String, icon: String, label: String, detail: String) -> some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(BrewTheme.Color.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text(detail)
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            }
        }
    }
}

// MARK: - Taste Share Card (ImageRenderer target)

private struct TasteShareCardView: View {
    var profile: TasteProfile
    var user: BrewUser?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("brew")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text(profile.identityLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                if let user {
                    Text("@\(user.username)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            HStack(spacing: 8) {
                chipLabel("Sweet \(Int(profile.averageSweetness.rounded()))/5")
                chipLabel("Strong \(Int(profile.averageStrength.rounded()))/5")
                chipLabel(profile.roastCounts.filter { $0.value > 0 }.max(by: { $0.value < $1.value })?.key.label ?? "Mixed")
            }
        }
        .padding(20)
        .frame(width: 320, height: 200)
        .background(
            LinearGradient(
                colors: [Color(hue: 0.07, saturation: 0.65, brightness: 0.38), Color(hue: 0.07, saturation: 0.5, brightness: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func chipLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Rankings Share Card (ImageRenderer target)

private struct RankingsShareCardView: View {
    var logs: [DrinkLog]
    var user: BrewUser?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("brew.")
                        .font(.system(size: 16, weight: .black, design: .serif))
                        .foregroundStyle(Color(hue: 0.07, saturation: 0.7, brightness: 0.8))
                    if let user {
                        Text("@\(user.username)'s rankings")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "list.number")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 14)

            ForEach(Array(logs.enumerated()), id: \.element.id) { idx, log in
                HStack(spacing: 10) {
                    Text("#\(idx + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hue: 0.07, saturation: 0.7, brightness: 0.8))
                        .frame(width: 28, alignment: .leading)
                    Text(log.drinkName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(log.roast.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.vertical, 4)
                if idx < logs.count - 1 {
                    Divider().overlay(Color.white.opacity(0.1))
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 320, height: max(200, CGFloat(60 + logs.count * 36)))
        .background(
            LinearGradient(
                colors: [Color(hue: 0.07, saturation: 0.65, brightness: 0.28), Color(hue: 0.07, saturation: 0.5, brightness: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Comparison History

struct ComparisonHistoryView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var myComparisons: [Comparison] {
        store.comparisons
            .filter { $0.userID == store.currentUserID }
            .sorted { $0.comparedAt > $1.comparedAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if myComparisons.isEmpty {
                    VStack(spacing: BrewTheme.Spacing.md) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 44))
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                        Text("No comparisons yet")
                            .font(BrewTheme.Font.title3)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                        Text("Head-to-head results appear here\nafter you compare drinks.")
                            .font(BrewTheme.Font.callout)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: BrewTheme.Spacing.xs) {
                            ForEach(myComparisons) { comp in
                                compRow(comp)
                                    .padding(.horizontal, BrewTheme.Spacing.sm)
                            }
                        }
                        .padding(.vertical, BrewTheme.Spacing.sm)
                    }
                }
            }
            .navigationTitle("Comparisons")
            .navigationBarTitleDisplayMode(.inline)
            .brewScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
            }
        }
    }

    private func compRow(_ comp: Comparison) -> some View {
        let winner = store.drinkLogs.first { $0.id == comp.winnerLogID }
        let loser = store.drinkLogs.first { $0.id == comp.loserLogID }

        return BrewCard {
            HStack(spacing: BrewTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Winner", systemImage: "checkmark.circle.fill")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.success)
                    Text(winner?.drinkName ?? "Deleted")
                        .font(BrewTheme.Font.bodySemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right.2")
                    .font(.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Runner-up")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                    Text(loser?.drinkName ?? "Deleted")
                        .font(BrewTheme.Font.body)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(comp.comparedAt, style: .relative)
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Flavor word -> color (Profile page only)

// Semantic colors for every descriptor in SimpleFlavors.all; unknown words
// fall back to a stable hue derived from the word itself.
private enum FlavorPalette {
    static let hexByWord: [String: String] = [
        "Blackberry": "#4A2545", "Blueberry": "#3B4E7A", "Raspberry": "#B23A5E",
        "Peach": "#E8945A", "Apple": "#6E9E4F", "Orange": "#D97B18",
        "Lemon": "#C2A61B", "Grapefruit": "#D96A52",
        "Jasmine": "#7C9A5C", "Rose": "#C4608F", "Lavender": "#8E7CC3",
        "Caramel": "#B5651D", "Vanilla": "#A98A4E", "Maple": "#8F5B2B",
        "Honey": "#C29225", "Brown Sugar": "#9C6644",
        "Chocolate": "#5D3A1A", "Cocoa": "#6B4226", "Dark Chocolate": "#3B2314",
        "Almond": "#A9865B", "Hazelnut": "#8E6C4E", "Walnut": "#77563E",
        "Toasted Grain": "#A17F42", "Bread": "#B08D57",
        "Clove": "#7A4B2A", "Cinnamon": "#A05A2C",
        "Smoke": "#5C5C5C", "Tobacco": "#6E5335", "Cedar": "#7D5A44"
    ]

    static func color(for word: String) -> SwiftUI.Color {
        if let hex = hexByWord[word] {
            return SwiftUI.Color(hex: hex)
        }
        // Stable fallback hue for descriptors not in the map.
        let hue = Double(abs(word.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }) % 360) / 360.0
        return SwiftUI.Color(hue: hue, saturation: 0.55, brightness: 0.5)
    }
}
