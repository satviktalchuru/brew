import Foundation
import Observation
import UIKit

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
    var likeCounts: [UUID: Int]
    var pendingComparisonPairs: [(DrinkLog, DrinkLog)] = []
    var avatarImages: [UUID: Data] = [:]

    var notificationService: NotificationService?
    var locationService: LocationService?

    func formattedDistance(to shop: Shop) -> String {
        locationService?.formattedDistance(to: shop.coordinate) ?? shop.distance
    }

    init(
        currentUserID: UUID,
        users: [BrewUser],
        shops: [Shop],
        drinkLogs: [DrinkLog],
        friendships: [Friendship],
        chatRequests: [CoffeeChatRequest],
        comparisons: [Comparison],
        likedLogIDs: Set<UUID>,
        likeCounts: [UUID: Int] = [:]
    ) {
        self.currentUserID = currentUserID
        self.users = users
        self.shops = shops
        self.drinkLogs = drinkLogs
        self.friendships = friendships
        self.chatRequests = chatRequests
        self.comparisons = comparisons
        self.likedLogIDs = likedLogIDs
        self.likeCounts = likeCounts
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

    func deleteDrinkLog(id: UUID) {
        drinkLogs.removeAll { $0.id == id && $0.userID == currentUserID }
        comparisons.removeAll { $0.winnerLogID == id || $0.loserLogID == id }
    }

    func toggleLike(logID: UUID) {
        guard drinkLogs.contains(where: { $0.id == logID }) else { return }
        if likedLogIDs.contains(logID) {
            likedLogIDs.remove(logID)
            likeCounts[logID] = max((likeCounts[logID] ?? 1) - 1, 0)
        } else {
            likedLogIDs.insert(logID)
            likeCounts[logID] = (likeCounts[logID] ?? 0) + 1
        }
    }

    func likeCount(for logID: UUID) -> Int {
        likeCounts[logID] ?? 0
    }

    func sendChatRequest(to addresseeID: UUID, at shopID: UUID) {
        guard addresseeID != currentUserID else { return }
        let alreadyExists = chatRequests.contains {
            $0.requesterID == currentUserID &&
            $0.addresseeID == addresseeID &&
            $0.shopID == shopID &&
            $0.status == .pending
        }
        guard !alreadyExists else { return }
        chatRequests.append(CoffeeChatRequest(
            id: UUID(),
            requesterID: currentUserID,
            addresseeID: addresseeID,
            shopID: shopID,
            status: .pending,
            requestedAt: .now
        ))
        if let requester = user(id: currentUserID), let shop = shop(id: shopID) {
            notificationService?.scheduleChatRequestNotification(from: requester.displayName, shopName: shop.name)
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

    func setAvatar(data: Data) {
        avatarImages[currentUserID] = data
    }

    func avatarImage(for userID: UUID) -> UIImage? {
        avatarImages[userID].flatMap { UIImage(data: $0) }
    }

    func tasteMatchScore(with userID: UUID) -> Int {
        TasteProfileEngine.matchScore(userA: currentUserID, userB: userID, logs: drinkLogs)
    }

    // MARK: - Friend Requests

    func sendFriendRequest(to userID: UUID) {
        guard userID != currentUserID else { return }
        let alreadyExists = friendships.contains {
            (($0.requesterID == currentUserID && $0.addresseeID == userID) ||
             ($0.requesterID == userID && $0.addresseeID == currentUserID))
        }
        guard !alreadyExists else { return }
        friendships.append(Friendship(id: UUID(), requesterID: currentUserID, addresseeID: userID, status: .pending))
        if let requester = user(id: currentUserID) {
            notificationService?.scheduleFriendRequestNotification(from: requester.displayName)
        }
    }

    func cancelFriendRequest(to userID: UUID) {
        friendships.removeAll {
            $0.requesterID == currentUserID && $0.addresseeID == userID && $0.status == .pending
        }
    }

    func acceptFriendRequest(from userID: UUID) {
        guard let idx = friendships.firstIndex(where: {
            $0.requesterID == userID && $0.addresseeID == currentUserID && $0.status == .pending
        }) else { return }
        friendships[idx].status = .accepted
    }

    func declineFriendRequest(from userID: UUID) {
        friendships.removeAll {
            $0.requesterID == userID && $0.addresseeID == currentUserID && $0.status == .pending
        }
    }

    func friendshipStatus(with userID: UUID) -> Friendship.Status? {
        friendships.first {
            ($0.requesterID == currentUserID && $0.addresseeID == userID) ||
            ($0.requesterID == userID && $0.addresseeID == currentUserID)
        }?.status
    }

    var pendingInboundRequests: [Friendship] {
        friendships.filter { $0.addresseeID == currentUserID && $0.status == .pending }
    }

    // MARK: - Analytics / Discovery

    func trendingDrinks(limit: Int = 8) -> [DrinkLog] {
        let cutoff = Date.now.addingTimeInterval(-14 * 24 * 3600)
        var winCounts: [UUID: Int] = [:]
        for comp in comparisons where comp.comparedAt >= cutoff {
            winCounts[comp.winnerLogID, default: 0] += 1
        }
        return drinkLogs
            .sorted { lhs, rhs in
                let wl = winCounts[lhs.id] ?? 0
                let wr = winCounts[rhs.id] ?? 0
                return wl != wr ? wl > wr : lhs.eloScore > rhs.eloScore
            }
            .prefix(limit)
            .map { $0 }
    }

    func updateDrinkLog(_ updated: DrinkLog) {
        guard let idx = drinkLogs.firstIndex(where: { $0.id == updated.id && $0.userID == currentUserID }) else { return }
        drinkLogs[idx] = updated
    }

    var logStreak: Int {
        let cal = Calendar.current
        let myLogs = drinkLogs.filter { $0.userID == currentUserID }
        guard !myLogs.isEmpty else { return 0 }
        let loggedDays = Set(myLogs.map { cal.startOfDay(for: $0.loggedAt) })
        var streak = 0
        var day = cal.startOfDay(for: .now)
        if !loggedDays.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while loggedDays.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    var pendingDeepLink: DeepLink? = nil

    var activityEvents: [ActivityEvent] {
        var events: [ActivityEvent] = []

        for f in pendingInboundRequests {
            events.append(ActivityEvent(kind: .friendRequest(f), date: .now))
        }

        for req in chatRequests where req.addresseeID == currentUserID && req.status == .pending {
            if let s = shop(id: req.shopID) {
                events.append(ActivityEvent(kind: .chatRequest(req, s), date: req.requestedAt))
            }
        }

        let fIDs: Set<UUID> = {
            let ids = friendships.filter { $0.status == .accepted }.flatMap { [$0.requesterID, $0.addresseeID] }
            return Set(ids).subtracting([currentUserID])
        }()
        let cutoff = Date.now.addingTimeInterval(-7 * 24 * 3600)
        for log in drinkLogs where fIDs.contains(log.userID) && log.loggedAt >= cutoff {
            if let u = user(id: log.userID) {
                events.append(ActivityEvent(kind: .friendLog(log, u), date: log.loggedAt))
            }
        }

        return events.sorted { $0.date > $1.date }
    }

    // MARK: - Supabase sync stub

    func refreshFeed() async {
        // TODO: replace with SupabaseService calls once credentials are set
        // e.g. let logs = try await supabase.fetchDrinkLogs(userID: currentUserID, accessToken: token)
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
