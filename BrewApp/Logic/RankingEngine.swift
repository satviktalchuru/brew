import Foundation

enum RankingEngine {
    static func rankedLogs(_ logs: [DrinkLog], includeHomeBrews: Bool) -> [DrinkLog] {
        logs
            .filter { includeHomeBrews || !$0.isHomeBrew }
            .sorted {
                if $0.eloScore == $1.eloScore {
                    return $0.loggedAt > $1.loggedAt
                }
                return $0.eloScore > $1.eloScore
            }
    }

    static func candidatePairs(
        logs: [DrinkLog],
        comparisons: [Comparison],
        userID: UUID,
        limit: Int
    ) -> [(DrinkLog, DrinkLog)] {
        guard limit > 0 else { return [] }

        let userLogs = logs
            .filter { $0.userID == userID }
            .sorted { $0.loggedAt > $1.loggedAt }
        let existingComparisons = comparisons.filter { $0.userID == userID }

        var pairs: [(DrinkLog, DrinkLog)] = []
        for firstIndex in userLogs.indices {
            for secondIndex in userLogs.indices.dropFirst(firstIndex + 1) {
                let first = userLogs[firstIndex]
                let second = userLogs[secondIndex]
                guard !existingComparisons.contains(where: { $0.matches(first.id, second.id) }) else {
                    continue
                }
                pairs.append((first, second))
            }
        }

        return pairs
            .sorted {
                let firstDistance = abs($0.0.eloScore - $0.1.eloScore)
                let secondDistance = abs($1.0.eloScore - $1.1.eloScore)
                if firstDistance == secondDistance {
                    return max($0.0.loggedAt, $0.1.loggedAt) > max($1.0.loggedAt, $1.1.loggedAt)
                }
                return firstDistance < secondDistance
            }
            .prefix(limit)
            .map { $0 }
    }
}
