import Foundation
import CoreLocation

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
    var latitude: Double = 40.7580
    var longitude: Double = -73.9855

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
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

// MARK: - Shop gradient

extension Shop {
    var accentHue: Double {
        let hues: [Double] = [0.07, 0.62, 0.35, 0.55, 0.10, 0.70, 0.45, 0.82, 0.17, 0.50]
        return hues[abs(name.hashValue) % hues.count]
    }
}

// MARK: - Activity Events

struct ActivityEvent: Identifiable {
    enum Kind {
        case friendRequest(Friendship)
        case chatRequest(CoffeeChatRequest, Shop)
        case friendLog(DrinkLog, BrewUser)
    }
    var id = UUID()
    var kind: Kind
    var date: Date

    var title: String {
        switch kind {
        case .friendRequest: return "Friend request"
        case .chatRequest(_, let shop): return "Coffee chat at \(shop.name)"
        case .friendLog(let log, let user):
            return "\(user.displayName.components(separatedBy: " ").first ?? user.displayName) logged \(log.drinkName)"
        }
    }

    var subtitle: String {
        switch kind {
        case .friendRequest: return "Wants to connect on Brew"
        case .chatRequest: return "Wants to meet for coffee"
        case .friendLog(let log, _):
            return log.isHomeBrew ? "Home brew" : "\(log.roast.label) · \(log.brewMethod.label)"
        }
    }

    var systemImage: String {
        switch kind {
        case .friendRequest: return "person.badge.plus.fill"
        case .chatRequest: return "bubble.left.and.bubble.right.fill"
        case .friendLog: return "cup.and.saucer.fill"
        }
    }
}

enum DeepLink: Equatable {
    case shop(UUID)
    case drink(UUID)

    init?(url: URL) {
        guard url.scheme == "brew" else { return nil }
        let host = url.host ?? ""
        let id = url.pathComponents.dropFirst().first.flatMap { UUID(uuidString: $0) }
        switch host {
        case "shop":  guard let id else { return nil }; self = .shop(id)
        case "drink": guard let id else { return nil }; self = .drink(id)
        default: return nil
        }
    }
}
