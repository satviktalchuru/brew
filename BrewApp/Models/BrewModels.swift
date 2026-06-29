import Foundation

enum Roast: String, CaseIterable, Identifiable, Codable {
    case light, medium, dark, unknown
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum BrewMethod: String, CaseIterable, Identifiable, Codable {
    case espresso, pourOver, coldBrew, latte, cappuccino, cortado, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pourOver: return "Pour Over"
        case .coldBrew: return "Cold Brew"
        default: return rawValue.capitalized
        }
    }
}

enum WouldOrder: String, CaseIterable, Identifiable, Codable {
    case yes, maybe, no
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct BrewUser: Identifiable, Hashable, Codable {
    var id: UUID
    var username: String
    var displayName: String
    var initials: String
    var isCurrentUser: Bool
    var isPublic: Bool
    var appearInChats: Bool
}

struct Shop: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var address: String
    var hours: String
    var distance: String
    var heroSymbol: String
}

struct FlavorTag: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var category: String
    var subcategory: String
    var descriptor: String
}

struct DrinkLog: Identifiable, Hashable, Codable {
    var id: UUID
    var userID: UUID
    var shopID: UUID?
    var isHomeBrew: Bool
    var drinkName: String
    var brewMethod: BrewMethod
    var roast: Roast
    var sweetness: Int
    var strength: Int
    var wouldOrder: WouldOrder
    var notes: String
    var flavorTags: [FlavorTag]
    var eloScore: Double
    var loggedAt: Date
}

struct Friendship: Identifiable, Hashable, Codable {
    enum Status: String, Codable {
        case pending, accepted, blocked
    }

    var id: UUID
    var requesterID: UUID
    var addresseeID: UUID
    var status: Status
}

struct CoffeeChatRequest: Identifiable, Hashable, Codable {
    enum Status: String, Codable {
        case pending, accepted, declined
    }

    var id: UUID
    var requesterID: UUID
    var addresseeID: UUID
    var shopID: UUID
    var status: Status
    var requestedAt: Date
}

struct Comparison: Identifiable, Hashable, Codable {
    var id: UUID
    var userID: UUID
    var winnerLogID: UUID
    var loserLogID: UUID
    var comparedAt: Date

    func matches(_ first: UUID, _ second: UUID) -> Bool {
        (winnerLogID == first && loserLogID == second) || (winnerLogID == second && loserLogID == first)
    }
}
