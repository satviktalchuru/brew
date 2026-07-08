import SwiftUI

struct BrewCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = BrewTheme.Spacing.sm, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(BrewTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                    .stroke(BrewTheme.Color.border.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: BrewTheme.Color.roastDark.opacity(0.07), radius: 12, x: 0, y: 6)
    }
}

struct BrewChip: View {
    enum Style {
        case accent
        case neutral
        case success
        case roast(Roast)
    }

    var title: String
    var systemImage: String?
    var style: Style = .accent

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(BrewTheme.Font.captionSemibold)
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, BrewTheme.Spacing.xs)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
        // The capsule always stretches to fit its word on one line; wrapping
        // containers (FlowLine) move whole chips to the next row instead of
        // breaking text inside the oval.
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var backgroundColor: Color {
        switch style {
        case .accent:
            return BrewTheme.Color.accentLight
        case .neutral:
            return BrewTheme.Color.background
        case .success:
            return BrewTheme.Color.success.opacity(0.14)
        case .roast(let roast):
            return BrewTheme.Color.roast(roast).opacity(roast == .dark ? 1 : 0.22)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .accent:
            return BrewTheme.Color.accent
        case .neutral:
            return BrewTheme.Color.textSecondary
        case .success:
            return BrewTheme.Color.success
        case .roast(let roast):
            return roast == .dark ? BrewTheme.Color.raisedSurface : BrewTheme.Color.roast(roast)
        }
    }
}

struct DotRating: View {
    var value: Int
    var total: Int = 5
    var label: String?

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.xs) {
            if let label {
                Text(label)
                    .font(BrewTheme.Font.captionSemibold)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            }

            HStack(spacing: BrewTheme.Spacing.xxs) {
                ForEach(1...max(total, 1), id: \.self) { dot in
                    Circle()
                        .fill(dot <= clampedValue ? BrewTheme.Color.accent : BrewTheme.Color.border)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var clampedValue: Int {
        min(max(value, 0), max(total, 1))
    }

    private var accessibilityText: String {
        let prefix = label.map { "\($0): " } ?? ""
        return "\(prefix)\(clampedValue) out of \(max(total, 1))"
    }
}

struct AvatarView: View {
    var initials: String
    var size: CGFloat = 44
    var image: UIImage? = nil
    var avatarURL: URL? = nil
    private var accessibilityDescription: String

    init(initials: String, size: CGFloat = 44, image: UIImage? = nil) {
        self.initials = initials
        self.size = size
        self.image = image
        self.accessibilityDescription = "Avatar \(initials)"
    }

    // Explicit `image` (used for the signed-in user's own avatar right after
    // picking a new photo, before the upload round-trip finishes) takes
    // priority; otherwise falls back to the user's synced avatar URL so
    // friends' real photos render instead of always showing initials.
    init(user: BrewUser, size: CGFloat = 44, image: UIImage? = nil) {
        self.initials = user.initials
        self.size = size
        self.image = image
        self.avatarURL = image == nil ? user.avatarURL.flatMap(URL.init(string:)) : nil
        self.accessibilityDescription = user.displayName
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    if case .success(let loaded) = phase {
                        loaded.resizable().scaledToFill()
                    } else {
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(BrewTheme.Color.raisedSurface.opacity(0.85), lineWidth: 2)
        }
        .accessibilityLabel(accessibilityDescription)
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: max(size * 0.34, 11), weight: .semibold, design: .default))
            .foregroundStyle(BrewTheme.Color.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size, height: size)
            .background(BrewTheme.Color.accentLight)
    }
}

struct BrewPrimaryButton: View {
    var title: String
    var systemImage: String?
    var isDisabled: Bool
    var action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: BrewTheme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .font(.system(.body, design: .default).weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(isDisabled ? BrewTheme.Color.textTertiary : BrewTheme.Color.accent)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
    }
}

// In-content page title. Replaces UIKit large navigation titles, which
// clip/shift when rendered inside the paged (swipeable) root TabView.
struct BrewPageTitle: View {
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(BrewTheme.Font.heading(size: 30, weight: .bold, relativeTo: .largeTitle))
            .foregroundStyle(BrewTheme.Color.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BrewSectionLabel: View {
    var title: String
    var subtitle: String?
    var systemImage: String?

    init(_ title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewTheme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrewTheme.Color.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrewTheme.Font.title3)
                    .foregroundStyle(BrewTheme.Color.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(BrewTheme.Font.footnote)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .textCase(nil)
    }
}

struct DrinkSummaryCard: View {
    var store: AppStore
    var log: DrinkLog
    var shop: Shop?
    var user: BrewUser?
    var showUser: Bool = true

    private var isLiked: Bool { store.likedLogIDs.contains(log.id) }
    private var likeCount: Int { store.likeCount(for: log.id) }

    var body: some View {
        BrewCard {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                header

                VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                    Text(log.drinkName)
                        .font(BrewTheme.Font.title2)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                        .lineLimit(2)

                    Text(contextText)
                        .font(BrewTheme.Font.callout)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }

                chipRow

                FlowLine {
                    DotRating(value: log.sweetness, label: "Sweet")
                    DotRating(value: log.strength, label: "Strong")
                }

                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(BrewTheme.Font.callout)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                        .lineLimit(3)
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if showUser, let user {
            HStack(spacing: BrewTheme.Spacing.xs) {
                AvatarView(user: user, size: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(user.displayName)
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    Text("@\(user.username)")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                }

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.toggleLike(logID: log.id)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.callout)
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(BrewTheme.Font.caption)
                        }
                    }
                    .foregroundStyle(isLiked ? BrewTheme.Color.accent : BrewTheme.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chipRow: some View {
        FlowLine {
            BrewChip(title: log.brewMethod.label, systemImage: "cup.and.saucer.fill")
            BrewChip(title: log.roast.label, style: .roast(log.roast))

            ForEach(log.flavorTags.prefix(2)) { tag in
                BrewChip(title: tag.descriptor, style: .neutral)
            }
        }
    }

    private var contextText: String {
        if log.isHomeBrew {
            return "Home brew"
        }

        return shop?.name ?? "Coffee shop"
    }
}

// Generated "brand" thumbnail for a drink's shop: a gradient in the shop's
// signature color with its logo mark and monogram. Stands in for real photos
// until a photo source (e.g. Google Places) is wired in.
struct CoffeeBrandTile: View {
    var shop: Shop?
    var log: DrinkLog
    var height: CGFloat = 96

    private var hue: Double { shop?.accentHue ?? 0.08 }
    private var symbol: String {
        shop?.heroSymbol ?? (log.isHomeBrew ? "house.fill" : "cup.and.saucer.fill")
    }
    private var monogram: String {
        let source = shop?.name ?? log.drinkName
        return source.first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.6, brightness: 0.55),
                    Color(hue: hue, saturation: 0.55, brightness: 0.3)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Image(systemName: symbol)
                .font(.system(size: height * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text(monogram)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.22))
                        .clipShape(Circle())
                    Spacer()
                    if log.isHomeBrew {
                        Text("Home")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.22))
                            .clipShape(Capsule())
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct RankedDrinkRow: View {
    var rank: Int
    var log: DrinkLog
    var shop: Shop?

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            Text("\(rank)")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()
                .padding(.horizontal, BrewTheme.Spacing.xs)
                .padding(.vertical, 6)
                .frame(minWidth: 34, minHeight: 34)
                .background(BrewTheme.Color.accentLight)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xxs) {
                Text(log.drinkName)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(BrewTheme.Font.footnote)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: BrewTheme.Spacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(log.eloScore.rounded()))")
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)

                Text("score")
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
            }
        }
        .padding(BrewTheme.Spacing.sm)
        .background(BrewTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                .stroke(BrewTheme.Color.border.opacity(0.7), lineWidth: 1)
        }
    }

    private var subtitle: String {
        let location = log.isHomeBrew ? "Home brew" : shop?.name ?? "Coffee shop"
        return "\(location) - \(log.brewMethod.label) - \(log.roast.label)"
    }
}

struct FlowLine<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        FlowLayout(spacing: BrewTheme.Spacing.xs, rowSpacing: BrewTheme.Spacing.xs) {
            content
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, availableWidth: availableWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + rowSpacing * CGFloat(max(rows.count - 1, 0))

        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        let rows = rows(for: subviews, availableWidth: bounds.width)

        for row in rows {
            origin.x = bounds.minX

            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: origin.x, y: origin.y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                origin.x += item.size.width + spacing
            }

            origin.y += row.height + rowSpacing
        }
    }

    private func rows(for subviews: Subviews, availableWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        let constrainedWidth = availableWidth.isFinite ? max(availableWidth, 0) : .infinity

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if !currentItems.isEmpty && nextWidth > constrainedWidth {
                rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    var items: [FlowItem]
    var width: CGFloat
    var height: CGFloat
}

private struct FlowItem {
    var index: Int
    var size: CGSize
}

// MARK: - Report Sheet (Apple Guideline 1.2 — mechanism to report content)

struct ReportSheet: View {
    var store: AppStore
    var reportedUserID: UUID?
    var reportedLogID: UUID?
    var onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var selectedPreset: String? = nil

    private let presets = ["Spam", "Harassment or abuse", "Inappropriate content", "Fake account", "Other"]

    private var canSubmit: Bool { !finalReason.trimmingCharacters(in: .whitespaces).isEmpty }
    private var finalReason: String {
        if let selectedPreset, selectedPreset != "Other" { return selectedPreset }
        return reason
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What's wrong?") {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            HStack {
                                Text(preset).foregroundStyle(BrewTheme.Color.textPrimary)
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark").foregroundStyle(BrewTheme.Color.accent)
                                }
                            }
                        }
                    }
                }

                if selectedPreset == "Other" || selectedPreset == nil {
                    Section("Details") {
                        TextField("Describe the issue", text: $reason, axis: .vertical)
                            .lineLimit(2...5)
                            .foregroundStyle(.black)
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let text = String(finalReason.prefix(500))
                        if let reportedUserID { store.reportUser(reportedUserID, reason: text) }
                        if let reportedLogID { store.reportLog(reportedLogID, reason: text) }
                        dismiss()
                        onSubmitted()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}
