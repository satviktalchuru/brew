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
            }

            Text(title)
                .font(BrewTheme.Font.captionSemibold)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, BrewTheme.Spacing.xs)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
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
            .accessibilityLabel(accessibilityText)
        }
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

    init(initials: String, size: CGFloat = 44) {
        self.initials = initials
        self.size = size
    }

    init(user: BrewUser, size: CGFloat = 44) {
        self.initials = user.initials
        self.size = size
    }

    var body: some View {
        Text(initials)
            .font(.system(size: max(size * 0.34, 11), weight: .semibold, design: .default))
            .foregroundStyle(BrewTheme.Color.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size, height: size)
            .background(BrewTheme.Color.accentLight)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(BrewTheme.Color.raisedSurface.opacity(0.85), lineWidth: 2)
            }
            .accessibilityLabel("Avatar \(initials)")
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
            .frame(height: 52)
            .background(isDisabled ? BrewTheme.Color.textTertiary : BrewTheme.Color.accent)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
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
    var log: DrinkLog
    var shop: Shop?
    var user: BrewUser?
    var showUser: Bool = true

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

                HStack(spacing: BrewTheme.Spacing.sm) {
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

                Image(systemName: log.wouldOrder == .yes ? "heart.fill" : "heart")
                    .foregroundStyle(log.wouldOrder == .yes ? BrewTheme.Color.accent : BrewTheme.Color.textTertiary)
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

struct RankedDrinkRow: View {
    var rank: Int
    var log: DrinkLog
    var shop: Shop?

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            Text("\(rank)")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.accent)
                .frame(width: 34, height: 34)
                .background(BrewTheme.Color.accentLight)
                .clipShape(Circle())

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

private struct FlowLine<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.xs) {
            content
        }
        .lineLimit(1)
    }
}
