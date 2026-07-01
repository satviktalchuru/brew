import Foundation
import CoreLocation

struct QuizProfile {
    var sweetness: Int
    var strength: Int
    var roast: Roast

    static var `default`: QuizProfile { QuizProfile(sweetness: 3, strength: 3, roast: .medium) }
}

struct ShopRecommendation: Identifiable {
    var id: UUID { shop.id }
    var shop: Shop
    var matchScore: Int
    var topDrink: DrinkLog?
    var reason: String
    var distance: String?
}

enum RecommendationEngine {

    static func recommendations(
        for profile: QuizProfile,
        shops: [Shop],
        logs: [DrinkLog],
        locationService: LocationService? = nil,
        limit: Int = 3
    ) -> [ShopRecommendation] {
        let scored = shops.map { shop -> ShopRecommendation in
            let shopLogs = logs.filter { $0.shopID == shop.id }
            let topDrink = shopLogs.max(by: { $0.eloScore < $1.eloScore })
            let dist = locationService?.formattedDistance(to: shop.coordinate) ?? shop.distance

            guard !shopLogs.isEmpty else {
                return ShopRecommendation(
                    shop: shop,
                    matchScore: 55,
                    topDrink: nil,
                    reason: "A local favourite worth exploring",
                    distance: dist
                )
            }

            let count = Double(shopLogs.count)
            let avgSweet  = shopLogs.map(\.sweetness).reduce(0, +).asDouble / count
            let avgStrong = shopLogs.map(\.strength).reduce(0, +).asDouble / count
            let roastCounts = Dictionary(grouping: shopLogs.map(\.roast), by: { $0 }).mapValues(\.count)
            let dominantRoast = roastCounts.max(by: { $0.value < $1.value })?.key ?? .medium

            let sweetMatch    = 1.0 - abs(avgSweet - profile.sweetness.asDouble) / 4.0
            let strengthMatch = 1.0 - abs(avgStrong - profile.strength.asDouble) / 4.0
            let roastMatch: Double = dominantRoast == profile.roast ? 1.0
                : abs(dominantRoast.sortOrder - profile.roast.sortOrder) == 1 ? 0.6 : 0.2

            let score = Int(((sweetMatch * 0.35 + strengthMatch * 0.35 + roastMatch * 0.30) * 100).rounded())
            let reason = makeReason(profile: profile, dominant: dominantRoast, avgSweet: avgSweet, avgStrong: avgStrong)

            return ShopRecommendation(shop: shop, matchScore: min(score, 99), topDrink: topDrink, reason: reason, distance: dist)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.matchScore != rhs.matchScore { return lhs.matchScore > rhs.matchScore }
                let dL = locationService?.distanceMeters(to: lhs.shop.coordinate) ?? .infinity
                let dR = locationService?.distanceMeters(to: rhs.shop.coordinate) ?? .infinity
                return dL < dR
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func makeReason(
        profile: QuizProfile,
        dominant: Roast,
        avgSweet: Double,
        avgStrong: Double
    ) -> String {
        if dominant == profile.roast && profile.sweetness >= 4 {
            return "Sweet \(dominant.label.lowercased()) roasts — right in your zone"
        }
        if dominant == profile.roast {
            return "Known for \(dominant.label.lowercased()) roasts, just like you prefer"
        }
        if profile.strength >= 4 && avgStrong >= 3.5 {
            return "Bold, intense drinks that match your strength preference"
        }
        if profile.sweetness >= 4 && avgSweet >= 3.5 {
            return "Sweeter profiles that match your taste"
        }
        if profile.roast == .light {
            return "Bright, fruity flavors — great for lighter palates"
        }
        return "A solid match for your overall taste profile"
    }
}

private extension Int {
    var asDouble: Double { Double(self) }
}

private extension Roast {
    var sortOrder: Int {
        switch self {
        case .light:  return 0
        case .medium: return 1
        case .dark:   return 2
        }
    }
}
