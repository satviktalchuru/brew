import Foundation

// MARK: - Date helpers

enum SupabaseDate {
    // Supabase/PostgREST returns timestamptz like "2026-07-01T15:21:00.123456+00:00".
    // Parse leniently (with and without fractional seconds); emit with fractional seconds.
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }

    static func string(from date: Date) -> String {
        withFraction.string(from: date)
    }
}

// MARK: - DrinkLog <-> RemoteDrinkLog

extension RemoteDrinkLog {
    init(_ log: DrinkLog) {
        self.init(
            id: log.id.uuidString,
            userID: log.userID.uuidString,
            shopID: log.shopID?.uuidString,
            isHomeBrew: log.isHomeBrew,
            drinkName: log.drinkName,
            brewMethod: log.brewMethod.rawValue,
            roast: log.roast.rawValue,
            sweetness: log.sweetness,
            strength: log.strength,
            wouldOrder: log.wouldOrder.rawValue,
            notes: log.notes,
            eloScore: log.eloScore,
            loggedAt: SupabaseDate.string(from: log.loggedAt),
            flavorTags: log.flavorTags.map {
                ["category": $0.category, "subcategory": $0.subcategory, "descriptor": $0.descriptor]
            }
        )
    }

    func toDrinkLog() -> DrinkLog? {
        guard let uuid = UUID(uuidString: id),
              let userUUID = UUID(uuidString: userID),
              let loggedDate = SupabaseDate.parse(loggedAt)
        else { return nil }

        let tags: [FlavorTag] = (flavorTags ?? []).map { dict in
            FlavorTag(
                id: UUID(),
                category: dict["category"] ?? "Other",
                subcategory: dict["subcategory"] ?? "Other",
                descriptor: dict["descriptor"] ?? ""
            )
        }

        return DrinkLog(
            id: uuid,
            userID: userUUID,
            shopID: shopID.flatMap { UUID(uuidString: $0) },
            isHomeBrew: isHomeBrew,
            drinkName: drinkName,
            brewMethod: BrewMethod(rawValue: brewMethod) ?? .other,
            roast: Roast(rawValue: roast) ?? .unknown,
            sweetness: sweetness,
            strength: strength,
            wouldOrder: WouldOrder(rawValue: wouldOrder) ?? .yes,
            notes: notes,
            flavorTags: tags,
            eloScore: eloScore,
            loggedAt: loggedDate
        )
    }
}

// MARK: - BrewUser <-> RemoteUser

extension RemoteUser {
    init(_ user: BrewUser) {
        self.init(
            id: user.id.uuidString,
            username: user.username,
            displayName: user.displayName,
            isPublic: user.isPublic,
            appearInChats: user.appearInChats
        )
    }

    func toBrewUser(isCurrentUser: Bool = false) -> BrewUser? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        let initials = trimmed
            .components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
        return BrewUser(
            id: uuid,
            username: username,
            displayName: displayName,
            initials: initials.isEmpty ? "?" : initials,
            isCurrentUser: isCurrentUser,
            isPublic: isPublic,
            appearInChats: appearInChats
        )
    }
}

// MARK: - Friendship <-> RemoteFriendship

extension RemoteFriendship {
    init(_ f: Friendship) {
        self.init(
            id: f.id.uuidString,
            requesterID: f.requesterID.uuidString,
            addresseeID: f.addresseeID.uuidString,
            status: f.status.rawValue
        )
    }

    func toFriendship() -> Friendship? {
        guard let uuid = UUID(uuidString: id),
              let req = UUID(uuidString: requesterID),
              let add = UUID(uuidString: addresseeID)
        else { return nil }
        return Friendship(
            id: uuid,
            requesterID: req,
            addresseeID: add,
            status: Friendship.Status(rawValue: status) ?? .pending
        )
    }
}

// MARK: - WishlistItem <-> RemoteWishlistItem

extension RemoteWishlistItem {
    init(_ item: WishlistItem) {
        self.init(
            id: item.id.uuidString,
            userID: item.userID.uuidString,
            shopID: item.shopID?.uuidString,
            title: item.title,
            note: item.note,
            createdAt: SupabaseDate.string(from: item.createdAt)
        )
    }

    func toWishlistItem() -> WishlistItem? {
        guard let uuid = UUID(uuidString: id),
              let userUUID = UUID(uuidString: userID),
              let created = SupabaseDate.parse(createdAt)
        else { return nil }
        return WishlistItem(
            id: uuid,
            userID: userUUID,
            shopID: shopID.flatMap { UUID(uuidString: $0) },
            title: title,
            note: note,
            createdAt: created
        )
    }
}

// MARK: - CoffeeChatRequest <-> RemoteChatRequest

extension RemoteChatRequest {
    init(_ r: CoffeeChatRequest) {
        self.init(
            id: r.id.uuidString,
            requesterID: r.requesterID.uuidString,
            addresseeID: r.addresseeID.uuidString,
            shopID: r.shopID.uuidString,
            status: r.status.rawValue,
            requestedAt: SupabaseDate.string(from: r.requestedAt)
        )
    }

    func toChatRequest() -> CoffeeChatRequest? {
        guard let uuid = UUID(uuidString: id),
              let req = UUID(uuidString: requesterID),
              let add = UUID(uuidString: addresseeID),
              let shop = UUID(uuidString: shopID),
              let date = SupabaseDate.parse(requestedAt)
        else { return nil }
        return CoffeeChatRequest(
            id: uuid,
            requesterID: req,
            addresseeID: add,
            shopID: shop,
            status: CoffeeChatRequest.Status(rawValue: status) ?? .pending,
            requestedAt: date
        )
    }
}
