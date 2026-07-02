import SwiftUI

// "Want to Try" — coffees/shops the user has saved to try later.
struct WishlistView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    private var items: [WishlistItem] { store.myWishlist }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(items) { item in
                            WishlistRow(item: item, shop: item.shopID.flatMap { store.shop(id: $0) })
                                .listRowBackground(BrewTheme.Color.surface)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { store.removeWishlistItem(id: items[i].id) }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(BrewTheme.Color.background)
                }
            }
            .navigationTitle("Want to Try")
            .navigationBarTitleDisplayMode(.inline)
            .brewScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add to wishlist")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddWishlistSheet(store: store)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BrewTheme.Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(BrewTheme.Color.textTertiary)
            Text("Nothing saved yet")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
            Text("Save coffees and shops you want to try.\nTap + to add one.")
                .font(BrewTheme.Font.callout)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WishlistRow: View {
    var item: WishlistItem
    var shop: Shop?

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            ZStack {
                Circle().fill(BrewTheme.Color.accentLight)
                Image(systemName: "bookmark.fill")
                    .font(.callout)
                    .foregroundStyle(BrewTheme.Color.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)
                if let shop {
                    Label(shop.name, systemImage: "mappin.circle.fill")
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                        .lineLimit(1)
                }
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(BrewTheme.Font.caption)
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
    }
}

private struct AddWishlistSheet: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var selectedShop: Shop?

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("What do you want to try?") {
                    TextField("e.g. Iced lavender latte", text: $title)
                        .foregroundStyle(.black)
                        .padding(BrewTheme.Spacing.sm)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))
                }

                Section("Shop (optional)") {
                    Menu {
                        Button("None") { selectedShop = nil }
                        ForEach(store.shops) { shop in
                            Button(shop.name) { selectedShop = shop }
                        }
                    } label: {
                        HStack {
                            Text(selectedShop?.name ?? "Choose a shop")
                                .foregroundStyle(selectedShop != nil ? BrewTheme.Color.textPrimary : BrewTheme.Color.textTertiary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                        }
                    }
                }

                Section("Note (optional)") {
                    TextField("Why do you want to try it?", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                        .foregroundStyle(.black)
                        .padding(BrewTheme.Spacing.sm)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrewTheme.Color.background)
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addWishlistItem(title: title, shopID: selectedShop?.id, note: note)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSave ? BrewTheme.Color.accent : BrewTheme.Color.textTertiary)
                    .disabled(!canSave)
                }
            }
        }
    }
}
