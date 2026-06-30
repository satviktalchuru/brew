import Foundation
import Observation

@Observable
final class AppStore {
    var currentUserID: UUID
    var users: [BrewUser]
    var shops: [Shop]
    var drinkLogs: [DrinkLog]
    var friendships: [Friendship]
    var chatRequests: [CoffeeChatRequest]
    var comparisons: [Comparison]
    var likedLogIDs: Set<UUID>
    var pendingComparisonPairs: [(DrinkLog, DrinkLog)] = []

    init(
        currentUserID: UUID,
        users: [BrewUser],
        shops: [Shop],
        drinkLogs: [DrinkLog],
        friendships: [Friendship],
        chatRequests: [CoffeeChatRequest],
        comparisons: [Comparison],
        likedLogIDs: Set<UUID>
    ) {
        self.currentUserID = currentUserID
        self.users = users
        self.shops = shops
        self.drinkLogs = drinkLogs
        self.friendships = friendships
        self.chatRequests = chatRequests
        self.comparisons = comparisons
        self.likedLogIDs = likedLogIDs
    }

    static func seeded() -> AppStore {
        MockData.makeStore()
    }

    func shop(id: UUID) -> Shop? {
        shops.first { $0.id == id }
    }

    func user(id: UUID) -> BrewUser? {
        users.first { $0.id == id }
    }

    func addDrinkLog(_ log: DrinkLog) {
        drinkLogs.append(log)
    }

    func toggleLike(logID: UUID) {
        guard drinkLogs.contains(where: { $0.id == logID }) else {
            return
        }

        if likedLogIDs.contains(logID) {
            likedLogIDs.remove(logID)
        } else {
            likedLogIDs.insert(logID)
        }
    }

    func recordComparison(winnerID: UUID, loserID: UUID) {
        guard winnerID != loserID,
              let winnerIndex = drinkLogs.firstIndex(where: { $0.id == winnerID }),
              let loserIndex = drinkLogs.firstIndex(where: { $0.id == loserID }),
              drinkLogs[winnerIndex].userID == currentUserID,
              drinkLogs[loserIndex].userID == currentUserID
        else {
            return
        }

        let updatedScores = EloCalculator.updatedScores(
            winner: drinkLogs[winnerIndex].eloScore,
            loser: drinkLogs[loserIndex].eloScore
        )
        drinkLogs[winnerIndex].eloScore = updatedScores.winner
        drinkLogs[loserIndex].eloScore = updatedScores.loser
        comparisons.append(
            Comparison(
                id: UUID(),
                userID: currentUserID,
                winnerLogID: winnerID,
                loserLogID: loserID,
                comparedAt: .now
            )
        )
    }

    func candidateComparisonPairs() -> [(DrinkLog, DrinkLog)] {
        let pairs = RankingEngine.candidatePairs(
            logs: drinkLogs,
            comparisons: comparisons,
            userID: currentUserID,
            limit: 10
        )
        pendingComparisonPairs = pairs
        return pairs
    }

    func rankedDrinks(includeHomeBrews: Bool) -> [DrinkLog] {
        RankingEngine.rankedLogs(
            drinkLogs.filter { $0.userID == currentUserID },
            includeHomeBrews: includeHomeBrews
        )
    }

    func tasteProfile(for userID: UUID) -> TasteProfile {
        TasteProfileEngine.profile(for: userID, logs: drinkLogs)
    }

    func acceptChatRequest(_ id: UUID) {
        updateChatRequest(id, status: .accepted)
    }

    func declineChatRequest(_ id: UUID) {
        updateChatRequest(id, status: .declined)
    }

    private func updateChatRequest(_ id: UUID, status: CoffeeChatRequest.Status) {
        guard let index = chatRequests.firstIndex(where: { $0.id == id }) else {
            return
        }
        chatRequests[index].status = status
    }
}
