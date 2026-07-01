import SwiftUI

struct TasteRecapView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var year: Int { Calendar.current.component(.year, from: .now) }

    private var myLogs: [DrinkLog] {
        store.drinkLogs.filter { $0.userID == store.currentUserID }
    }

    private var yearLogs: [DrinkLog] {
        myLogs.filter { Calendar.current.component(.year, from: $0.loggedAt) == year }
    }

    private var profile: TasteProfile { store.tasteProfile(for: store.currentUserID) }

    private var topDrink: DrinkLog? { store.rankedDrinks(includeHomeBrews: true).first }

    private var mostVisitedShop: (Shop, Int)? {
        let counts = Dictionary(grouping: yearLogs.compactMap(\.shopID), by: { $0 }).mapValues(\.count)
        guard let topID = counts.max(by: { $0.value < $1.value })?.key,
              let shop = store.shop(id: topID) else { return nil }
        return (shop, counts[topID] ?? 0)
    }

    private var totalComparisons: Int {
        store.comparisons.filter { $0.userID == store.currentUserID }.count
    }

    private var shopCount: Int { Set(yearLogs.compactMap(\.shopID)).count }

    @State private var cardIndex: Int = 0

    private var cards: [AnyView] {
        var result: [AnyView] = [AnyView(heroCard), AnyView(statsGrid)]
        if topDrink != nil { result.append(AnyView(topDrinkCard)) }
        if mostVisitedShop != nil { result.append(AnyView(topShopCard)) }
        result.append(AnyView(flavorCard))
        result.append(AnyView(identityCard))
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(recapHex: "#1A0F07").ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    cards[cardIndex]
                        .id(cardIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: cardIndex)
                        .padding(.horizontal, BrewTheme.Spacing.md)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        ForEach(0..<cards.count, id: \.self) { i in
                            Circle()
                                .fill(i == cardIndex ? Color(recapHex: "#C65B1A") : .white.opacity(0.25))
                                .frame(width: i == cardIndex ? 8 : 5, height: i == cardIndex ? 8 : 5)
                                .animation(.spring(response: 0.3), value: cardIndex)
                        }
                    }
                    .padding(.bottom, BrewTheme.Spacing.sm)

                    HStack(spacing: BrewTheme.Spacing.md) {
                        if cardIndex > 0 {
                            Button {
                                withAnimation { cardIndex -= 1 }
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, BrewTheme.Spacing.md)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                        if cardIndex < cards.count - 1 {
                            Button {
                                withAnimation { cardIndex += 1 }
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, BrewTheme.Spacing.md)
                                    .padding(.vertical, 10)
                                    .background(Color(recapHex: "#C65B1A"))
                                    .clipShape(Capsule())
                            }
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Text("Finish")
                                    .font(BrewTheme.Font.bodySemibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, BrewTheme.Spacing.lg)
                                    .padding(.vertical, 10)
                                    .background(Color(recapHex: "#C65B1A"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, BrewTheme.Spacing.md)
                    .padding(.bottom, BrewTheme.Spacing.lg)
                }
            }
            .navigationTitle("\(year) in Brew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            Text("\(year)")
                .font(.system(size: 72, weight: .black, design: .serif))
                .foregroundStyle(Color(recapHex: "#C65B1A"))
            Text("in Brew")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(.white.opacity(0.8))
            Text("\(yearLogs.count) drinks logged")
                .font(BrewTheme.Font.callout)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrewTheme.Spacing.xl)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrewTheme.Spacing.sm) {
            recapStat(value: "\(yearLogs.count)", label: "Drinks Logged")
            recapStat(value: "\(shopCount)", label: "Shops Visited")
            recapStat(value: "\(totalComparisons)", label: "Comparisons")
            recapStat(value: profile.identityLabel, label: "Your Identity", small: true)
        }
        .padding(.horizontal, BrewTheme.Spacing.md)
        .padding(.bottom, BrewTheme.Spacing.md)
    }

    private func recapStat(value: String, label: String, small: Bool = false) -> some View {
        VStack(spacing: BrewTheme.Spacing.xxs) {
            Text(value)
                .font(small ? .system(size: 18, weight: .bold, design: .serif) : .system(size: 36, weight: .black, design: .serif))
                .foregroundStyle(Color(recapHex: "#C65B1A"))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(label)
                .font(BrewTheme.Font.caption)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(BrewTheme.Spacing.md)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var topDrinkCard: some View {
        if let drink = topDrink {
            recapSection(title: "Your #1 Drink") {
                VStack(spacing: BrewTheme.Spacing.xs) {
                    Text(drink.drinkName)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let shopID = drink.shopID, let shop = store.shop(id: shopID) {
                        Text("at \(shop.name)").font(BrewTheme.Font.callout).foregroundStyle(.white.opacity(0.6))
                    }
                    BrewChip(title: drink.roast.label, style: .roast(drink.roast))
                }
            }
        }
    }

    @ViewBuilder
    private var topShopCard: some View {
        if let (shop, visits) = mostVisitedShop {
            recapSection(title: "Your Go-To Spot") {
                VStack(spacing: BrewTheme.Spacing.xs) {
                    Text(shop.name).font(.system(size: 26, weight: .bold, design: .serif)).foregroundStyle(.white)
                    Text("\(visits) visit\(visits == 1 ? "" : "s") this year").font(BrewTheme.Font.callout).foregroundStyle(.white.opacity(0.6))
                    Label(shop.address, systemImage: "mappin.circle.fill").font(BrewTheme.Font.caption).foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private var flavorCard: some View {
        recapSection(title: "Your Flavor Map") {
            VStack(spacing: BrewTheme.Spacing.sm) {
                FlavorWheelView(tags: myLogs.flatMap(\.flavorTags), size: 200)
                if !profile.topFlavorDescriptors.isEmpty {
                    HStack(spacing: BrewTheme.Spacing.xs) {
                        ForEach(profile.topFlavorDescriptors.prefix(4), id: \.self) { f in
                            BrewChip(title: f, style: .neutral)
                        }
                    }
                }
            }
        }
    }

    private var identityCard: some View {
        recapSection(title: "You are a") {
            VStack(spacing: BrewTheme.Spacing.sm) {
                Text(profile.identityLabel)
                    .font(.system(size: 32, weight: .black, design: .serif))
                    .foregroundStyle(Color(recapHex: "#C65B1A"))
                    .multilineTextAlignment(.center)
                HStack(spacing: BrewTheme.Spacing.lg) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", profile.averageSweetness)).font(.title2.bold()).foregroundStyle(.white)
                        Text("Sweetness").font(BrewTheme.Font.caption).foregroundStyle(.white.opacity(0.5))
                    }
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", profile.averageStrength)).font(.title2.bold()).foregroundStyle(.white)
                        Text("Strength").font(BrewTheme.Font.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    private func recapSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            Text(title)
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            content().frame(maxWidth: .infinity)
        }
        .padding(BrewTheme.Spacing.md)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.large, style: .continuous))
        .padding(.horizontal, BrewTheme.Spacing.md)
        .padding(.bottom, BrewTheme.Spacing.sm)
    }
}

private extension Color {
    init(recapHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = UInt64(h, radix: 16) ?? 0
        self.init(red: Double((n >> 16) & 0xFF) / 255, green: Double((n >> 8) & 0xFF) / 255, blue: Double(n & 0xFF) / 255)
    }
}
