import SwiftUI

struct HeadToHeadView: View {
    var store: AppStore
    var pairs: [(DrinkLog, DrinkLog)]
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var selectedID: UUID?
    @State private var comparisonsCompleted = 0
    @State private var preSessionSnapshot: [UUID: (rank: Int, score: Double)] = [:]

    private var currentPair: (DrinkLog, DrinkLog)? {
        guard currentIndex < pairs.count else { return nil }
        return pairs[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let (left, right) = currentPair {
                    progressIndicator
                        .padding(.top, BrewTheme.Spacing.sm)

                    Spacer()

                    VStack(spacing: BrewTheme.Spacing.xs) {
                        Text("Which did you prefer?")
                            .font(BrewTheme.Font.title2)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Tap a card to select, then confirm.")
                            .font(BrewTheme.Font.footnote)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }
                    .padding(.horizontal, BrewTheme.Spacing.sm)

                    Spacer()

                    HStack(alignment: .top, spacing: BrewTheme.Spacing.sm) {
                        ComparisonCard(
                            log: left,
                            shop: left.shopID.flatMap { store.shop(id: $0) },
                            isSelected: selectedID == left.id
                        ) { selectedID = left.id }
                        .padding(.leading, BrewTheme.Spacing.sm)

                        VStack {
                            Spacer()
                            Text("VS")
                                .font(BrewTheme.Font.captionSemibold)
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                            Spacer()
                        }
                        .frame(width: 28)

                        ComparisonCard(
                            log: right,
                            shop: right.shopID.flatMap { store.shop(id: $0) },
                            isSelected: selectedID == right.id
                        ) { selectedID = right.id }
                        .padding(.trailing, BrewTheme.Spacing.sm)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()

                    VStack(spacing: BrewTheme.Spacing.xs) {
                        BrewPrimaryButton(
                            "Pick This One",
                            isDisabled: selectedID == nil
                        ) {
                            guard let winner = selectedID else { return }
                            let loser = (left.id == winner) ? right.id : left.id
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.recordComparison(winnerID: winner, loserID: loser)
                            comparisonsCompleted += 1
                            advance()
                        }

                        Button("Skip") { advance() }
                            .font(BrewTheme.Font.callout)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                    .padding(.bottom, BrewTheme.Spacing.lg)
                } else {
                    doneState
                }
            }
            .brewScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let ranked = store.rankedDrinks(includeHomeBrews: true)
                preSessionSnapshot = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { idx, log in
                    (log.id, (rank: idx + 1, score: log.eloScore))
                })
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { finish() }
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Progress

    private var progressIndicator: some View {
        HStack(spacing: BrewTheme.Spacing.xs) {
            ForEach(0..<max(pairs.count, 1), id: \.self) { i in
                Capsule()
                    .fill(i <= currentIndex ? BrewTheme.Color.accent : BrewTheme.Color.border)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    // MARK: - Done State

    private var doneState: some View {
        ScrollView {
            VStack(spacing: BrewTheme.Spacing.lg) {
                VStack(spacing: BrewTheme.Spacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(BrewTheme.Color.accent)
                        .padding(.top, BrewTheme.Spacing.xl)

                    Text("Session complete!")
                        .font(BrewTheme.Font.title2)
                        .foregroundStyle(BrewTheme.Color.textPrimary)

                    Text("\(comparisonsCompleted) comparison\(comparisonsCompleted == 1 ? "" : "s") made")
                        .font(BrewTheme.Font.callout)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }

                if !rankMovers.isEmpty {
                    VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                        Text("How things moved")
                            .font(BrewTheme.Font.captionSemibold)
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal, BrewTheme.Spacing.sm)

                        ForEach(rankMovers, id: \.log.id) { mover in
                            moverRow(mover)
                        }
                    }
                }

                BrewPrimaryButton("See My Rankings") { finish() }
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                    .padding(.bottom, BrewTheme.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moverRow(_ mover: (log: DrinkLog, from: Int, to: Int)) -> some View {
        let delta = mover.from - mover.to
        let up = delta > 0
        return HStack(spacing: BrewTheme.Spacing.sm) {
            Image(systemName: up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(up ? BrewTheme.Color.success : BrewTheme.Color.textTertiary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(mover.log.drinkName)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)
                Text("#\(mover.from) → #\(mover.to)")
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            }

            Spacer()

            Text(up ? "+\(delta)" : "\(delta)")
                .font(BrewTheme.Font.bodySemibold)
                .foregroundStyle(up ? BrewTheme.Color.success : BrewTheme.Color.textTertiary)
        }
        .padding(.horizontal, BrewTheme.Spacing.sm)
        .padding(.vertical, BrewTheme.Spacing.xs)
        .background(BrewTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small, style: .continuous))
        .padding(.horizontal, BrewTheme.Spacing.sm)
    }

    private var rankMovers: [(log: DrinkLog, from: Int, to: Int)] {
        guard !preSessionSnapshot.isEmpty else { return [] }
        let newRanked = store.rankedDrinks(includeHomeBrews: true)
        return newRanked.enumerated().compactMap { idx, log -> (DrinkLog, Int, Int)? in
            guard let pre = preSessionSnapshot[log.id] else { return nil }
            let newRank = idx + 1
            guard newRank != pre.rank else { return nil }
            return (log, pre.rank, newRank)
        }
        .prefix(4)
        .map { $0 }
    }

    // MARK: - Helpers

    private func advance() {
        selectedID = nil
        currentIndex += 1
    }

    private func finish() {
        onDone()
        dismiss()
    }
}

// MARK: - Comparison Card

private struct ComparisonCard: View {
    var log: DrinkLog
    var shop: Shop?
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                Text(log.drinkName)
                    .font(BrewTheme.Font.title3)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(log.isHomeBrew ? "Home brew" : (shop?.name ?? "Coffee shop"))
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: BrewTheme.Spacing.xs)

                BrewChip(title: log.roast.label, style: .roast(log.roast))
                BrewChip(title: log.brewMethod.label, systemImage: "cup.and.saucer.fill")

                DotRating(value: log.sweetness, label: "Sweet")
                DotRating(value: log.strength, label: "Strong")
            }
            .padding(BrewTheme.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(BrewTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                    .stroke(
                        isSelected ? BrewTheme.Color.accent : BrewTheme.Color.border.opacity(0.7),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }
            .shadow(color: BrewTheme.Color.roastDark.opacity(isSelected ? 0.14 : 0.06), radius: 12, x: 0, y: 6)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
