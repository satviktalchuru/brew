import SwiftUI
import MapKit

struct ExploreView: View {
    var store: AppStore
    @State private var searchText = ""
    @State private var showMap = false
    @State private var selectedShop: Shop?
    @State private var activeFilter: ExploreFilter = .all

    enum ExploreFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case espresso = "Espresso"
        case pourOver = "Pour Over"
        case coldBrew = "Cold Brew"
        case latte = "Latte"
        var id: String { rawValue }

        var method: BrewMethod? {
            switch self {
            case .all: return nil
            case .espresso: return .espresso
            case .pourOver: return .pourOver
            case .coldBrew: return .coldBrew
            case .latte: return .latte
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if showMap {
                    mapView
                } else {
                    listView
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search coffee shops")
            .brewScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showMap.toggle() }
                    } label: {
                        Image(systemName: showMap ? "list.bullet" : "map")
                    }
                }
            }
            .navigationDestination(for: Shop.self) { shop in
                ShopDetailView(store: store, shop: shop)
            }
            .navigationDestination(for: DrinkLog.self) { log in
                DrinkDetailView(store: store, log: log)
            }
        }
    }

    // MARK: - List

    private var listView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                filterChips
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                    .padding(.top, BrewTheme.Spacing.xs)

                trendingSection

                BrewSectionLabel("Coffee Shops", systemImage: "mappin.circle.fill")
                    .padding(.horizontal, BrewTheme.Spacing.sm)

                if filteredShops.isEmpty {
                    Text("No shops match your filter.")
                        .font(BrewTheme.Font.callout)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                } else {
                    ForEach(filteredShops) { shop in
                        NavigationLink(value: shop) {
                            ShopRowCard(store: store, shop: shop, logCount: logCount(for: shop))
                                .padding(.horizontal, BrewTheme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, BrewTheme.Spacing.sm)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrewTheme.Spacing.xs) {
                ForEach(ExploreFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.25)) { activeFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(BrewTheme.Font.captionSemibold)
                            .foregroundStyle(activeFilter == filter ? .white : BrewTheme.Color.accent)
                            .padding(.horizontal, BrewTheme.Spacing.sm)
                            .padding(.vertical, 8)
                            .background(activeFilter == filter ? BrewTheme.Color.accent : BrewTheme.Color.accentLight)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Trending Section

    private var trendingSection: some View {
        let trending = store.trendingDrinks(limit: 8)
        guard !trending.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                BrewSectionLabel("Trending", subtitle: "Most compared this week", systemImage: "flame.fill")
                    .padding(.horizontal, BrewTheme.Spacing.sm)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrewTheme.Spacing.sm) {
                        ForEach(trending) { log in
                            NavigationLink(value: log) {
                                TrendingDrinkCard(
                                    log: log,
                                    shop: log.shopID.flatMap { store.shop(id: $0) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, BrewTheme.Spacing.sm)
                }
            }
        )
    }

    // MARK: - Map

    private var mapView: some View {
        Map(selection: $selectedShop) {
            ForEach(filteredShops) { shop in
                Marker(shop.name, systemImage: "cup.and.saucer.fill", coordinate: shop.coordinate)
                    .tint(BrewTheme.Color.accent)
                    .tag(shop)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .sheet(item: $selectedShop) { shop in
            NavigationStack {
                ShopDetailView(store: store, shop: shop)
            }
            .presentationDetents([.height(110), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    private var filteredShops: [Shop] {
        let text = searchText.isEmpty ? store.shops : store.shops.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.address.localizedCaseInsensitiveContains(searchText)
        }
        guard let method = activeFilter.method else { return text }
        return text.filter { shop in
            store.drinkLogs.contains { $0.shopID == shop.id && $0.brewMethod == method }
        }
    }

    private func logCount(for shop: Shop) -> Int {
        store.drinkLogs.filter { $0.shopID == shop.id }.count
    }
}

// MARK: - Shop Row Card

private struct ShopRowCard: View {
    var store: AppStore
    var shop: Shop
    var logCount: Int

    var body: some View {
        BrewCard {
            HStack(spacing: BrewTheme.Spacing.sm) {
                shopIcon

                VStack(alignment: .leading, spacing: BrewTheme.Spacing.xxs) {
                    Text(shop.name)
                        .font(BrewTheme.Font.title3)
                        .foregroundStyle(BrewTheme.Color.textPrimary)

                    Text(shop.address)
                        .font(BrewTheme.Font.footnote)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: BrewTheme.Spacing.xs) {
                        Label(store.formattedDistance(to: shop), systemImage: "location.fill")
                        if logCount > 0 {
                            Text("·")
                            Text("\(logCount) drink\(logCount == 1 ? "" : "s") logged")
                        }
                    }
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrewTheme.Color.textTertiary)
            }
        }
    }

    private var shopIcon: some View {
        Image(systemName: shop.heroSymbol)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(
                LinearGradient(
                    colors: [
                        Color(hue: shop.accentHue, saturation: 0.6, brightness: 0.55),
                        Color(hue: shop.accentHue, saturation: 0.5, brightness: 0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small, style: .continuous))
    }
}

// MARK: - Trending Drink Card

private struct TrendingDrinkCard: View {
    var log: DrinkLog
    var shop: Shop?

    var body: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(log.drinkName)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let shop {
                    Text(shop.name)
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }

            BrewChip(title: log.roast.label, style: .roast(log.roast))
        }
        .padding(BrewTheme.Spacing.sm)
        .frame(width: 140, height: 140, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(hue: shop?.accentHue ?? 0.07, saturation: 0.6, brightness: 0.45),
                    Color(hue: shop?.accentHue ?? 0.07, saturation: 0.5, brightness: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
    }
}
