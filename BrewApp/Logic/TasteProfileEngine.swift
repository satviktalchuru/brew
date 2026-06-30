import Foundation

struct TasteProfile: Equatable {
    var averageStrength: Double
    var averageSweetness: Double
    var roastCounts: [Roast: Int]
    var topFlavorDescriptors: [String]
    var dominantFamily: String?
    var identityLabel: String
}

enum TasteProfileEngine {
    static func profile(for userID: UUID, logs: [DrinkLog]) -> TasteProfile {
        let userLogs = logs.filter { $0.userID == userID }
        guard !userLogs.isEmpty else {
            return TasteProfile(
                averageStrength: 0,
                averageSweetness: 0,
                roastCounts: roastCounts(from: []),
                topFlavorDescriptors: [],
                dominantFamily: nil,
                identityLabel: "Balanced Explorer"
            )
        }

        let averageStrength = average(userLogs.map(\.strength))
        let averageSweetness = average(userLogs.map(\.sweetness))
        let roastCounts = roastCounts(from: userLogs.map(\.roast))
        let flavorTags = userLogs.flatMap(\.flavorTags)
        let topFlavorDescriptors = topValues(flavorTags.map(\.descriptor))
        let dominantFamily = dominantFlavorFamily(from: flavorTags)
        let identityLabel = identity(
            averageStrength: averageStrength,
            averageSweetness: averageSweetness,
            dominantFamily: dominantFamily
        )

        return TasteProfile(
            averageStrength: averageStrength,
            averageSweetness: averageSweetness,
            roastCounts: roastCounts,
            topFlavorDescriptors: topFlavorDescriptors,
            dominantFamily: dominantFamily,
            identityLabel: identityLabel
        )
    }

    private static func average(_ values: [Int]) -> Double {
        Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func roastCounts(from roasts: [Roast]) -> [Roast: Int] {
        var counts: [Roast: Int] = [
            .light: 0,
            .medium: 0,
            .dark: 0
        ]
        for roast in roasts {
            counts[roast, default: 0] += 1
        }
        return counts
    }

    private static func topValues(_ values: [String], limit: Int = 5) -> [String] {
        Dictionary(grouping: values, by: { $0 })
            .map { (value: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.value < $1.value
                }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0.value }
    }

    private static func dominantFlavorFamily(from tags: [FlavorTag]) -> String? {
        Dictionary(grouping: tags.map { family(for: $0.category) }, by: { $0 })
            .map { (family: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.family < $1.family
                }
                return $0.count > $1.count
            }
            .first?
            .family
    }

    private static func family(for category: String) -> String {
        switch category.lowercased() {
        case "fruit":
            return "Fruity"
        case "roast":
            return "Roasted"
        case "floral":
            return "Floral"
        default:
            return category
        }
    }

    private static func identity(
        averageStrength: Double,
        averageSweetness: Double,
        dominantFamily: String?
    ) -> String {
        if averageStrength > 3.5 && averageSweetness < 2.5 {
            return "Bold & Clean"
        }
        if averageSweetness > 3.5 && dominantFamily == "Fruity" {
            return "Sweet & Bright"
        }
        if dominantFamily == "Roasted" {
            return "Deep & Dark"
        }
        if dominantFamily == "Floral" {
            return "Delicate & Floral"
        }
        return "Balanced Explorer"
    }
}
