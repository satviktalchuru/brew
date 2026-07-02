import SwiftUI

// Beli-style placement: the freshly logged coffee is compared against the user's
// existing ranked list via binary search ("Better / About the same / Worse").
// Each answer halves the search range, so it takes ~log2(n) taps to find the
// exact rank. The result sets the new log's ELO between its neighbors.
struct RankPlacementView: View {
    var store: AppStore
    var newLog: DrinkLog
    var onComplete: (_ wantsMore: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("brew.rankingExplainerSeen") private var explainerSeen = false

    @State private var ranked: [DrinkLog] = []
    @State private var lo = 0
    @State private var hi = 0
    @State private var results: [(winner: UUID, loser: UUID)] = []
    @State private var isDone = false
    @State private var finalRank = 1
    @State private var showExplainer = false

    private let placementGap = 20.0

    private var mid: Int { (lo + hi) / 2 }
    private var opponent: DrinkLog? { (lo < hi && mid < ranked.count) ? ranked[mid] : nil }

    private var estimatedTaps: Int {
        max(1, Int(ceil(log2(Double(ranked.count + 1)))))
    }
    private var progress: Double {
        guard !ranked.isEmpty else { return 1 }
        return min(1, Double(results.count) / Double(estimatedTaps))
    }

    var body: some View {
        NavigationStack {
            Group {
                if showExplainer {
                    explainerScreen
                } else if isDone {
                    resultState
                } else if let opponent {
                    comparisonState(opponent)
                } else {
                    Color.clear.onAppear { finalize(at: lo) }
                }
            }
            .brewScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isDone && !showExplainer {
                        Button("Skip") { finalize(at: mid) }
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }
                }
            }
        }
        .onAppear(perform: setup)
        .interactiveDismissDisabled(!isDone)
    }

    // MARK: - Setup

    private func setup() {
        ranked = store.rankedDrinks(includeHomeBrews: true).filter { $0.id != newLog.id }
        lo = 0
        hi = ranked.count
        if ranked.isEmpty {
            finalize(at: 0)
        } else if !explainerSeen {
            showExplainer = true
        }
    }

    // MARK: - One-time explainer

    private var explainerScreen: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.lg) {
            Spacer(minLength: BrewTheme.Spacing.xl)

            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                Image(systemName: "list.number")
                    .font(.system(size: 40))
                    .foregroundStyle(BrewTheme.Color.accent)
                Text("How ranking works")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text("No star ratings here — you rank by comparing.")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: BrewTheme.Spacing.md) {
                explainerRow("1", "arrow.up.arrow.down", "We ask a few quick questions",
                             "Is this coffee better or worse than another you've had?")
                explainerRow("2", "chart.bar.fill", "Your ranked list builds itself",
                             "Each answer places it exactly where it belongs.")
                explainerRow("3", "sparkles", "Your taste profile gets smarter",
                             "The more you rank, the better your recommendations.")
            }

            Spacer()

            BrewPrimaryButton("Let's rank it") {
                explainerSeen = true
                withAnimation(.easeInOut(duration: 0.2)) { showExplainer = false }
            }
        }
        .padding(BrewTheme.Spacing.md)
    }

    private func explainerRow(_ number: String, _ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: BrewTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(BrewTheme.Color.accent)
                .frame(width: 34, height: 34)
                .background(BrewTheme.Color.accentLight)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text(detail)
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Comparison

    private func comparisonState(_ opponent: DrinkLog) -> some View {
        VStack(spacing: BrewTheme.Spacing.md) {
            progressBar
                .padding(.top, BrewTheme.Spacing.sm)

            Text("Where does it rank?")
                .font(BrewTheme.Font.title2)
                .foregroundStyle(BrewTheme.Color.textPrimary)

            newCoffeeHeader

            Text("compared to")
                .font(BrewTheme.Font.footnote)
                .foregroundStyle(BrewTheme.Color.textTertiary)
                .textCase(.uppercase)

            opponentCard(opponent)

            Spacer()

            VStack(spacing: BrewTheme.Spacing.xs) {
                choiceButton("Better", systemImage: "arrow.up", tint: BrewTheme.Color.success) {
                    choose(preferNew: true, opponent: opponent)
                }
                choiceButton("About the same", systemImage: "equal", tint: BrewTheme.Color.textSecondary) {
                    finalize(at: mid)
                }
                choiceButton("Worse", systemImage: "arrow.down", tint: BrewTheme.Color.textTertiary) {
                    choose(preferNew: false, opponent: opponent)
                }
            }
            .padding(.bottom, BrewTheme.Spacing.lg)
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    private var newCoffeeHeader: some View {
        VStack(spacing: BrewTheme.Spacing.xs) {
            CoffeeBrandTile(shop: newLog.shopID.flatMap { store.shop(id: $0) }, log: newLog, height: 110)
            HStack(spacing: BrewTheme.Spacing.xs) {
                Text("NEW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(BrewTheme.Color.accent)
                    .clipShape(Capsule())
                Text(newLog.drinkName)
                    .font(BrewTheme.Font.title3)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    private func opponentCard(_ opponent: DrinkLog) -> some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            CoffeeBrandTile(shop: opponent.shopID.flatMap { store.shop(id: $0) }, log: opponent, height: 56)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(opponent.drinkName)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)
                Text(opponent.isHomeBrew ? "Home brew" : (opponent.shopID.flatMap { store.shop(id: $0)?.name } ?? "Coffee shop"))
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(BrewTheme.Spacing.sm)
        .background(BrewTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                .stroke(BrewTheme.Color.border.opacity(0.7), lineWidth: 1)
        }
    }

    private func choiceButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: BrewTheme.Spacing.xs) {
                Image(systemName: systemImage)
                Text(title).font(BrewTheme.Font.bodySemibold)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(BrewTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(BrewTheme.Color.border).frame(height: 4)
                Capsule().fill(BrewTheme.Color.accent)
                    .frame(width: max(6, geo.size.width * progress), height: 4)
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.2), value: progress)
    }

    // MARK: - Logic

    private func choose(preferNew: Bool, opponent: DrinkLog) {
        if preferNew {
            results.append((winner: newLog.id, loser: opponent.id))
            hi = mid
        } else {
            results.append((winner: opponent.id, loser: newLog.id))
            lo = mid + 1
        }
        if lo >= hi { finalize(at: lo) }
    }

    private func finalize(at index: Int) {
        let n = ranked.count
        let clamped = min(max(index, 0), n)
        let score: Double
        if n == 0 {
            score = newLog.eloScore
        } else if clamped <= 0 {
            score = ranked[0].eloScore + placementGap
        } else if clamped >= n {
            score = ranked[n - 1].eloScore - placementGap
        } else {
            score = (ranked[clamped - 1].eloScore + ranked[clamped].eloScore) / 2
        }
        store.applyPlacement(logID: newLog.id, score: score, results: results)
        finalRank = clamped + 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDone = true }
    }

    // MARK: - Result

    private var resultState: some View {
        VStack(spacing: BrewTheme.Spacing.md) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(BrewTheme.Color.accent)

            Text("Ranked #\(finalRank) of \(ranked.count + 1)")
                .font(BrewTheme.Font.title2)
                .foregroundStyle(BrewTheme.Color.textPrimary)

            CoffeeBrandTile(shop: newLog.shopID.flatMap { store.shop(id: $0) }, log: newLog, height: 110)
                .padding(.horizontal, BrewTheme.Spacing.lg)

            Text(newLog.drinkName)
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)

            Spacer()

            VStack(spacing: BrewTheme.Spacing.xs) {
                BrewPrimaryButton("Done") {
                    onComplete(false)
                    dismiss()
                }
                if store.rankedDrinks(includeHomeBrews: true).count > 2 {
                    Button("Fine-tune my rankings") {
                        onComplete(true)
                        dismiss()
                    }
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                }
            }
            .padding(.horizontal, BrewTheme.Spacing.sm)
            .padding(.bottom, BrewTheme.Spacing.lg)
        }
    }
}
