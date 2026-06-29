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
}
