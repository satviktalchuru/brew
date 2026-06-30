import Foundation

enum EloCalculator {
    static let K_FACTOR = 32.0

    static func updatedScores(winner: Double, loser: Double) -> (winner: Double, loser: Double) {
        let winnerExpected = expectedScore(for: winner, against: loser)
        let loserExpected = expectedScore(for: loser, against: winner)

        return (
            winner: winner + K_FACTOR * (1 - winnerExpected),
            loser: loser + K_FACTOR * (0 - loserExpected)
        )
    }

    private static func expectedScore(for rating: Double, against opponentRating: Double) -> Double {
        1 / (1 + pow(10, (opponentRating - rating) / 400))
    }
}
