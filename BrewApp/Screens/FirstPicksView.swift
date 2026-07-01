import SwiftUI

struct FirstPicksView: View {
    var store: AppStore
    var locationService: LocationService
    var onStart: () -> Void

    @AppStorage("brew.quizSweetness") private var savedSweetness = 3
    @AppStorage("brew.quizStrength")  private var savedStrength  = 3
    @AppStorage("brew.quizRoast")     private var savedRoast     = "medium"

    @State private var appeared = false

    private var quizProfile: QuizProfile {
        QuizProfile(
            sweetness: savedSweetness,
            strength:  savedStrength,
            roast:     Roast(rawValue: savedRoast) ?? .medium
        )
    }

    private var recommendations: [ShopRecommendation] {
        RecommendationEngine.recommendations(
            for: quizProfile,
            shops: store.shops,
            logs: store.drinkLogs,
            locationService: locationService,
            limit: 3
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(fpHex: "#1A0F07"), Color(fpHex: "#2C1810")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                scrollContent
                bottomCTA
            }
        }
    }

    // MARK: - Scroll

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.lg) {
                header
                    .padding(.top, BrewTheme.Spacing.xl)

                VStack(spacing: BrewTheme.Spacing.sm) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                        RecommendationCard(rank: index + 1, rec: rec)
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.12),
                                value: appeared
                            )
                    }
                }

                tasteChips
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)
            }
            .padding(.horizontal, BrewTheme.Spacing.md)
            .padding(.bottom, 130)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            HStack(spacing: BrewTheme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(fpHex: "#C65B1A"))
                Text("Based on your taste")
                    .font(BrewTheme.Font.captionSemibold)
                    .foregroundStyle(Color(fpHex: "#C65B1A"))
                    .textCase(.uppercase)
            }

            Text("Your\nFirst Picks")
                .font(.system(size: 40, weight: .black, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(2)

            HStack(spacing: BrewTheme.Spacing.xs) {
                profilePill(icon: "drop.fill",  label: sweetLabel)
                profilePill(icon: "bolt.fill",  label: strengthLabel)
                profilePill(icon: "flame.fill", label: roastLabel)
            }
            .padding(.top, BrewTheme.Spacing.xxs)
        }
    }

    private func profilePill(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(BrewTheme.Font.caption)
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Flavor teaser

    private var tasteChips: some View {
        let flavors = Array(
            Set(recommendations.compactMap(\.topDrink).flatMap(\.flavorTags).map(\.descriptor))
        ).prefix(5)

        return VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Text("Flavors you'll find")
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)

            if !flavors.isEmpty {
                HStack(spacing: BrewTheme.Spacing.xs) {
                    ForEach(Array(flavors), id: \.self) { flavor in
                        Text(flavor)
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewTheme.Spacing.md)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.large, style: .continuous))
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: BrewTheme.Spacing.xs) {
            Button(action: onStart) {
                HStack(spacing: BrewTheme.Spacing.xs) {
                    Text("Start Brewing")
                        .font(BrewTheme.Font.bodySemibold)
                    Image(systemName: "arrow.right")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(fpHex: "#C65B1A"))
                .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
            }

            Text("Log your first drink and let the rankings begin")
                .font(BrewTheme.Font.caption)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, BrewTheme.Spacing.md)
        .padding(.bottom, BrewTheme.Spacing.lg)
        .padding(.top, BrewTheme.Spacing.sm)
        .background(
            LinearGradient(
                colors: [Color(fpHex: "#1A0F07").opacity(0), Color(fpHex: "#1A0F07")],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Label helpers

    private var sweetLabel: String {
        savedSweetness >= 4 ? "Sweet" : savedSweetness <= 2 ? "Unsweetened" : "Balanced"
    }
    private var strengthLabel: String {
        savedStrength >= 4 ? "Strong" : savedStrength <= 2 ? "Mild" : "Medium"
    }
    private var roastLabel: String {
        (Roast(rawValue: savedRoast) ?? .medium).label + " Roast"
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    var rank: Int
    var rec: ShopRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: BrewTheme.Spacing.sm) {
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(rank == 1 ? Color(fpHex: "#C65B1A") : .white.opacity(0.35))
                    .frame(width: 24, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(rec.shop.name)
                        .font(BrewTheme.Font.title3)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(rec.reason)
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 1) {
                    Text("\(rec.matchScore)%")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(fpHex: "#C65B1A"))
                    Text("match")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .textCase(.uppercase)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: BrewTheme.Spacing.md) {
                if let drink = rec.topDrink {
                    HStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.caption)
                            .foregroundStyle(Color(fpHex: "#C65B1A").opacity(0.8))
                        Text("Try: \(drink.drinkName)")
                            .font(BrewTheme.Font.captionSemibold)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let dist = rec.distance {
                    Label(dist, systemImage: "location.fill")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(BrewTheme.Spacing.md)
        .background(rank == 1 ? Color(fpHex: "#C65B1A").opacity(0.1) : .white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrewTheme.Radius.large, style: .continuous)
                .stroke(
                    rank == 1 ? Color(fpHex: "#C65B1A").opacity(0.4) : .white.opacity(0.07),
                    lineWidth: 1
                )
        }
    }
}

private extension Color {
    init(fpHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = UInt64(h, radix: 16) ?? 0
        self.init(red: Double((n >> 16) & 0xFF) / 255, green: Double((n >> 8) & 0xFF) / 255, blue: Double(n & 0xFF) / 255)
    }
}
