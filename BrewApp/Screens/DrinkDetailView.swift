import SwiftUI

struct DrinkDetailView: View {
    var store: AppStore
    var log: DrinkLog

    private var shop: Shop? { log.shopID.flatMap { store.shop(id: $0) } }
    private var user: BrewUser? { store.user(id: log.userID) }
    private var isOwn: Bool { log.userID == store.currentUserID }
    private var isLiked: Bool { store.likedLogIDs.contains(log.id) }
    // Read the live copy from the store so ELO reflects any re-ranking.
    private var live: DrinkLog { store.drinkLogs.first { $0.id == log.id } ?? log }
    private var canRerank: Bool { isOwn && store.rankedDrinks(includeHomeBrews: true).count > 1 }

    @State private var showEdit = false
    @State private var showRerank = false
    @State private var showReport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.md) {
                titleBlock
                metaRow
                ratingsBlock
                if !log.flavorTags.isEmpty { flavorsBlock }
                if !log.notes.isEmpty { notesBlock }
                actionsRow
            }
            .padding(BrewTheme.Spacing.sm)
        }
        .navigationTitle(log.drinkName)
        .navigationBarTitleDisplayMode(.large)
        .brewScreenBackground()
        .toolbar {
            if isOwn {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                        .foregroundStyle(BrewTheme.Color.accent)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showReport = true
                    } label: {
                        Image(systemName: "flag")
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            LogView(store: store, editingLog: log) { _ in }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(store: store, reportedUserID: nil, reportedLogID: log.id) {}
        }
        .sheet(isPresented: $showRerank) {
            RankPlacementView(store: store, newLog: live) { _ in }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xxs) {
            Text(log.drinkName)
                .font(BrewTheme.Font.title)
                .foregroundStyle(BrewTheme.Color.textPrimary)

            if log.isHomeBrew {
                Label("Home Brew", systemImage: "house.fill")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            } else if let shop {
                Label(shop.name, systemImage: "mappin.circle.fill")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.accent)
            }

            if let user {
                HStack(spacing: BrewTheme.Spacing.xs) {
                    AvatarView(user: user, size: 22)
                    Text(isOwn ? "You" : user.displayName)
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                    Text("·")
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                    Text(log.loggedAt, style: .relative)
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                }
            }
        }
    }

    // MARK: - Meta

    private var metaRow: some View {
        HStack(spacing: BrewTheme.Spacing.xs) {
            BrewChip(title: log.brewMethod.label, systemImage: "cup.and.saucer.fill")
            BrewChip(title: log.roast.label, style: .roast(log.roast))
            Spacer()
            wouldOrderBadge
        }
    }

    private var wouldOrderBadge: some View {
        let config: (String, BrewChip.Style) = switch log.wouldOrder {
        case .yes: ("Order Again ✓", .success)
        case .maybe: ("Maybe", .neutral)
        case .no: ("Wouldn't Order", .neutral)
        }
        return BrewChip(title: config.0, style: config.1)
    }

    // MARK: - Ratings

    private var ratingsBlock: some View {
        BrewCard {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                DotRating(value: log.sweetness, label: "Sweetness")
                DotRating(value: log.strength, label: "Strength")
                Divider()
                HStack {
                    Text("ELO Score")
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                    Spacer()
                    Text("\(Int(live.eloScore.rounded()))")
                        .font(BrewTheme.Font.bodySemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                }
                if canRerank {
                    Button {
                        showRerank = true
                    } label: {
                        Label("Re-rank this coffee", systemImage: "arrow.up.arrow.down")
                            .font(BrewTheme.Font.captionSemibold)
                            .foregroundStyle(BrewTheme.Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(BrewTheme.Color.accentLight)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Flavors

    private var flavorsBlock: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
            Text("Flavor Profile")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
                .padding(.horizontal, BrewTheme.Spacing.sm)

            HStack {
                Spacer()
                FlavorWheelView(tags: log.flavorTags, size: 220)
                Spacer()
            }

            FlavorWheelLegend(tags: log.flavorTags)

            HStack(spacing: BrewTheme.Spacing.xs) {
                ForEach(log.flavorTags) { tag in
                    BrewChip(title: tag.descriptor, style: .neutral)
                }
            }
            .padding(.horizontal, BrewTheme.Spacing.sm)
        }
    }

    // MARK: - Notes

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Text("Notes")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
            Text(log.notes)
                .font(BrewTheme.Font.callout)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .italic()
        }
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.toggleLike(logID: log.id)
            } label: {
                let count = store.likeCount(for: log.id)
                let label = count > 0 ? "\(count) \(isLiked ? "Liked" : "Like")" : (isLiked ? "Liked" : "Like")
                Label(label, systemImage: isLiked ? "heart.fill" : "heart")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(isLiked ? BrewTheme.Color.accent : BrewTheme.Color.textSecondary)
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                    .padding(.vertical, 8)
                    .background(isLiked ? BrewTheme.Color.accentLight : Color.clear)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(BrewTheme.Color.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)

            Spacer()

            ShareLink(item: renderedShareCard(), preview: SharePreview(log.drinkName, image: renderedShareCard())) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                    .padding(.vertical, 8)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(BrewTheme.Color.border, lineWidth: 1) }
            }
        }
    }

    @MainActor
    private func renderedShareCard() -> Image {
        let renderer = ImageRenderer(content: ShareCardView(log: log, shop: shop))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "cup.and.saucer.fill")
    }
}

// MARK: - Share Card

private struct ShareCardView: View {
    var log: DrinkLog
    var shop: Shop?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("brew")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(log.drinkName)
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let shop {
                    Text(shop.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            HStack(spacing: 8) {
                chipLabel(log.roast.label)
                chipLabel(log.brewMethod.label)
                chipLabel("ELO \(Int(log.eloScore))")
            }
        }
        .padding(20)
        .frame(width: 320, height: 200)
        .background(
            LinearGradient(
                colors: [Color(hue: 0.07, saturation: 0.7, brightness: 0.35), Color(hue: 0.07, saturation: 0.5, brightness: 0.2)],
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
