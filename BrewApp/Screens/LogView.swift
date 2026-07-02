import SwiftUI

struct LogView: View {
    var store: AppStore
    var editingLog: DrinkLog? = nil
    var onSaved: ([(DrinkLog, DrinkLog)]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isHomeBrew: Bool
    @State private var selectedShop: Shop?
    @State private var drinkName: String
    @State private var roast: Roast
    @State private var brewMethod: BrewMethod
    @State private var sweetness: Int
    @State private var strength: Int
    @State private var wouldOrder: WouldOrder
    @State private var notes: String
    @State private var selectedFlavors: [String]
    @State private var showShopPicker = false

    init(store: AppStore, editingLog: DrinkLog? = nil, onSaved: @escaping ([(DrinkLog, DrinkLog)]) -> Void) {
        self.store = store
        self.editingLog = editingLog
        self.onSaved = onSaved
        if let log = editingLog {
            _isHomeBrew = State(initialValue: log.isHomeBrew)
            _drinkName = State(initialValue: log.drinkName)
            _roast = State(initialValue: log.roast)
            _brewMethod = State(initialValue: log.brewMethod)
            _sweetness = State(initialValue: log.sweetness)
            _strength = State(initialValue: log.strength)
            _wouldOrder = State(initialValue: log.wouldOrder)
            _notes = State(initialValue: log.notes)
            _selectedFlavors = State(initialValue: log.flavorTags.map(\.descriptor))
            _selectedShop = State(initialValue: log.shopID.flatMap { id in store.shops.first { $0.id == id } })
        } else {
            _isHomeBrew = State(initialValue: false)
            _drinkName = State(initialValue: "")
            _roast = State(initialValue: .unknown)
            _brewMethod = State(initialValue: .espresso)
            _sweetness = State(initialValue: 3)
            _strength = State(initialValue: 3)
            _wouldOrder = State(initialValue: .yes)
            _notes = State(initialValue: "")
            _selectedFlavors = State(initialValue: [])
            _selectedShop = State(initialValue: nil)
        }
    }

    private var canSave: Bool { !drinkName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                drinkSection
                flavorSection
                notesSection
            }
            .scrollContentBackground(.hidden)
            .background(BrewTheme.Color.background)
            .navigationTitle(editingLog != nil ? "Edit Drink" : "Log a Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canSave ? BrewTheme.Color.accent : BrewTheme.Color.textTertiary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showShopPicker) {
                ShopPickerSheet(store: store, selected: $selectedShop)
            }
        }
    }

    // MARK: - Sections

    private var locationSection: some View {
        Section {
            Toggle(isOn: $isHomeBrew) {
                Label("Home Brew", systemImage: "house.fill")
                    .foregroundStyle(BrewTheme.Color.textPrimary)
            }
            .tint(BrewTheme.Color.accent)

            if !isHomeBrew {
                Button {
                    showShopPicker = true
                } label: {
                    HStack {
                        Label(
                            selectedShop?.name ?? "Choose a shop",
                            systemImage: "mappin.circle.fill"
                        )
                        .foregroundStyle(selectedShop != nil ? BrewTheme.Color.textPrimary : BrewTheme.Color.textTertiary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                    }
                }
            }
        } header: {
            Text("Where")
        }
    }

    private var drinkSection: some View {
        Section {
            TextField("What did you order?", text: $drinkName)
                .foregroundStyle(.black)
                .padding(BrewTheme.Spacing.sm)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))

            brewMethodPicker
            roastPicker
            DotStepper(label: "Sweetness", value: $sweetness)
            DotStepper(label: "Strength", value: $strength)
            wouldOrderPicker
        } header: {
            Text("Drink")
        }
    }

    private var brewMethodPicker: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Text("Method")
                .font(BrewTheme.Font.footnote)
                .foregroundStyle(BrewTheme.Color.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrewTheme.Spacing.xs) {
                    ForEach(BrewMethod.allCases) { method in
                        chipToggle(
                            title: method.label,
                            isSelected: brewMethod == method
                        ) { brewMethod = method }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
    }

    private var roastPicker: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Text("Roast")
                .font(BrewTheme.Font.footnote)
                .foregroundStyle(BrewTheme.Color.textSecondary)
            HStack(spacing: BrewTheme.Spacing.xs) {
                ForEach(Roast.allCases) { r in
                    chipToggle(
                        title: r.label,
                        isSelected: roast == r,
                        color: r == .unknown ? nil : BrewTheme.Color.roast(r)
                    ) { roast = r }
                }
            }
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
    }

    private var wouldOrderPicker: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            Text("Would you order again?")
                .font(BrewTheme.Font.footnote)
                .foregroundStyle(BrewTheme.Color.textSecondary)
            HStack(spacing: BrewTheme.Spacing.xs) {
                ForEach(WouldOrder.allCases) { w in
                    chipToggle(title: w.label, isSelected: wouldOrder == w) { wouldOrder = w }
                }
            }
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
    }

    private var flavorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
                Text("Pick up to 5 flavors you tasted")
                    .font(BrewTheme.Font.footnote)
                    .foregroundStyle(BrewTheme.Color.textSecondary)

                FlavorChipGrid(
                    options: SimpleFlavors.all,
                    selected: $selectedFlavors,
                    maxCount: 5
                )
            }
            .padding(.vertical, BrewTheme.Spacing.xxs)
        } header: {
            Text("Flavors (optional)")
        }
    }

    private var notesSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add a note...")
                        .foregroundStyle(Color.black.opacity(0.35))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .foregroundStyle(.black)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))
            }
        } header: {
            Text("Notes (optional)")
        }
    }

    // MARK: - Chip Toggle

    @ViewBuilder
    private func chipToggle(
        title: String,
        isSelected: Bool,
        color: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(isSelected ? .white : (color ?? BrewTheme.Color.accent))
                .padding(.horizontal, BrewTheme.Spacing.xs)
                .padding(.vertical, 6)
                .background(isSelected ? (color ?? BrewTheme.Color.accent) : (color ?? BrewTheme.Color.accent).opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        let tags = selectedFlavors.map { descriptor -> FlavorTag in
            let info = SimpleFlavors.info(for: descriptor)
            return FlavorTag(id: UUID(), category: info.category, subcategory: info.subcategory, descriptor: descriptor)
        }

        if let existing = editingLog {
            var updated = existing
            updated.shopID = isHomeBrew ? nil : selectedShop?.id
            updated.isHomeBrew = isHomeBrew
            updated.drinkName = drinkName.trimmingCharacters(in: .whitespaces)
            updated.brewMethod = brewMethod
            updated.roast = roast
            updated.sweetness = sweetness
            updated.strength = strength
            updated.wouldOrder = wouldOrder
            updated.notes = notes.trimmingCharacters(in: .whitespaces)
            updated.flavorTags = tags
            store.updateDrinkLog(updated)
            dismiss()
            onSaved([])
            return
        }

        let log = DrinkLog(
            id: UUID(),
            userID: store.currentUserID,
            shopID: isHomeBrew ? nil : selectedShop?.id,
            isHomeBrew: isHomeBrew,
            drinkName: drinkName.trimmingCharacters(in: .whitespaces),
            brewMethod: brewMethod,
            roast: roast,
            sweetness: sweetness,
            strength: strength,
            wouldOrder: wouldOrder,
            notes: notes.trimmingCharacters(in: .whitespaces),
            flavorTags: tags,
            eloScore: 1000,
            loggedAt: .now
        )

        store.addDrinkLog(log)
        let pairs = store.candidateComparisonPairs()
        dismiss()
        onSaved(pairs)
    }
}

// MARK: - Shop Picker Sheet

private struct ShopPickerSheet: View {
    var store: AppStore
    @Binding var selected: Shop?
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List(filtered) { shop in
                Button {
                    selected = shop
                    dismiss()
                } label: {
                    HStack {
                        Text(shop.name).foregroundStyle(BrewTheme.Color.textPrimary)
                        Spacer()
                        if selected?.id == shop.id {
                            Image(systemName: "checkmark").foregroundStyle(BrewTheme.Color.accent)
                        }
                    }
                }
            }
            .navigationTitle("Choose a Shop")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search shops")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var filtered: [Shop] {
        guard !search.isEmpty else { return store.shops }
        return store.shops.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
}

// MARK: - Dot Stepper

private struct DotStepper: View {
    var label: String
    @Binding var value: Int
    var total = 5

    var body: some View {
        HStack {
            Text(label)
                .font(BrewTheme.Font.footnote)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .frame(minWidth: 90, alignment: .leading)
            HStack(spacing: BrewTheme.Spacing.xs) {
                ForEach(1...total, id: \.self) { i in
                    Circle()
                        .fill(i <= value ? BrewTheme.Color.accent : BrewTheme.Color.border)
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                        .onTapGesture { value = i }
                }
            }
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
    }
}

// MARK: - Flavor Chip Grid

private struct FlavorChipGrid: View {
    var options: [String]
    @Binding var selected: [String]
    var maxCount: Int

    var body: some View {
        FlexWrap(spacing: 8) {
            ForEach(options, id: \.self) { flavor in
                let isOn = selected.contains(flavor)
                Button {
                    if isOn {
                        selected.removeAll { $0 == flavor }
                    } else if selected.count < maxCount {
                        selected.append(flavor)
                    }
                } label: {
                    Text(flavor)
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(isOn ? .white : BrewTheme.Color.accent)
                        .padding(.horizontal, BrewTheme.Spacing.xs)
                        .padding(.vertical, 6)
                        .background(isOn ? BrewTheme.Color.accent : BrewTheme.Color.accentLight)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isOn && selected.count >= maxCount)
                .opacity(!isOn && selected.count >= maxCount ? 0.4 : 1)
            }
        }
    }
}

private struct FlexWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, origin) in layout(subviews: subviews, width: bounds.width).origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}

// MARK: - Simple Flavor Data

enum SimpleFlavors {
    struct Info { var category: String; var subcategory: String }

    static let all: [String] = [
        "Blackberry", "Blueberry", "Raspberry", "Peach", "Apple",
        "Orange", "Lemon", "Grapefruit",
        "Jasmine", "Rose", "Lavender",
        "Caramel", "Vanilla", "Maple", "Honey", "Brown Sugar",
        "Chocolate", "Cocoa", "Dark Chocolate",
        "Almond", "Hazelnut", "Walnut",
        "Toasted Grain", "Bread", "Clove", "Cinnamon",
        "Smoke", "Tobacco", "Cedar"
    ]

    static func info(for descriptor: String) -> Info {
        switch descriptor {
        case "Blackberry", "Blueberry", "Raspberry": return Info(category: "Fruit", subcategory: "Berry")
        case "Peach", "Apple": return Info(category: "Fruit", subcategory: "Stone Fruit")
        case "Orange", "Lemon", "Grapefruit": return Info(category: "Fruit", subcategory: "Citrus")
        case "Jasmine", "Rose", "Lavender": return Info(category: "Floral", subcategory: "Fresh")
        case "Caramel", "Vanilla", "Maple", "Honey", "Brown Sugar": return Info(category: "Sweet", subcategory: "Sugar")
        case "Chocolate", "Cocoa", "Dark Chocolate": return Info(category: "Roast", subcategory: "Chocolate")
        case "Almond", "Hazelnut", "Walnut": return Info(category: "Nutty", subcategory: "Tree Nut")
        case "Toasted Grain", "Bread": return Info(category: "Roast", subcategory: "Toast")
        case "Clove", "Cinnamon": return Info(category: "Spice", subcategory: "Warm")
        default: return Info(category: "Other", subcategory: "Other")
        }
    }
}
