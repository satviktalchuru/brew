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
    var wishlist: [WishlistItem] = []
    var pendingComparisonPairs: [(DrinkLog, DrinkLog)] = []
    var avatarImages: [UUID: Data] = [:]

    var notificationService: NotificationService?
    var locationService: LocationService?

    // MARK: - Supabase sync state
    // When these are non-nil the store mirrors mutations to Supabase and
    // refreshFeed() pulls real data. In demo mode they stay nil and the
    // store runs entirely on seeded mock data.
    var supabase: SupabaseService?
    var accessToken: String?
    var authUserID: UUID?
    var isSyncing = false
    var syncError: String?
    // Returns a fresh access token when the current one is rejected (401).
    var tokenRefresher: (() async -> String?)?

    var isSyncConfigured: Bool { supabase != nil && accessToken != nil && authUserID != nil }

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
        likeCounts: [UUID: Int] = [:],
        wishlist: [WishlistItem] = []
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
        self.wishlist = wishlist
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
        if isSyncConfigured { pushInsertLog(log) }
    }

    func deleteDrinkLog(id: UUID) {
        drinkLogs.removeAll { $0.id == id && $0.userID == currentUserID }
        comparisons.removeAll { $0.winnerLogID == id || $0.loserLogID == id }
        if isSyncConfigured { pushDeleteLog(id: id) }
    }

    func toggleLike(logID: UUID) {
        guard drinkLogs.contains(where: { $0.id == logID }) else { return }
        let nowLiked: Bool
        if likedLogIDs.contains(logID) {
            likedLogIDs.remove(logID)
            likeCounts[logID] = max((likeCounts[logID] ?? 1) - 1, 0)
            nowLiked = false
        } else {
            likedLogIDs.insert(logID)
            likeCounts[logID] = (likeCounts[logID] ?? 0) + 1
            nowLiked = true
        }
        if isSyncConfigured { pushLike(logID: logID, liked: nowLiked) }
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
        let request = CoffeeChatRequest(
            id: UUID(),
            requesterID: currentUserID,
            addresseeID: addresseeID,
            shopID: shopID,
            status: .pending,
            requestedAt: .now
        )
        chatRequests.append(request)
        if isSyncConfigured { pushChatRequest(request) }
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
        if isSyncConfigured {
            pushUpdateLog(drinkLogs[winnerIndex])
            pushUpdateLog(drinkLogs[loserIndex])
        }
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
        let friendship = Friendship(id: UUID(), requesterID: currentUserID, addresseeID: userID, status: .pending)
        friendships.append(friendship)
        if isSyncConfigured { pushFriendship(friendship) }
        if let requester = user(id: currentUserID) {
            notificationService?.scheduleFriendRequestNotification(from: requester.displayName)
        }
    }

    func cancelFriendRequest(to userID: UUID) {
        let outgoing = friendships.first {
            $0.requesterID == currentUserID && $0.addresseeID == userID && $0.status == .pending
        }
        friendships.removeAll {
            $0.requesterID == currentUserID && $0.addresseeID == userID && $0.status == .pending
        }
        if isSyncConfigured, let id = outgoing?.id { pushFriendshipStatus(id: id, status: .blocked) }
    }

    func acceptFriendRequest(from userID: UUID) {
        guard let idx = friendships.firstIndex(where: {
            $0.requesterID == userID && $0.addresseeID == currentUserID && $0.status == .pending
        }) else { return }
        friendships[idx].status = .accepted
        if isSyncConfigured { pushFriendshipStatus(id: friendships[idx].id, status: .accepted) }
    }

    func declineFriendRequest(from userID: UUID) {
        let inbound = friendships.first {
            $0.requesterID == userID && $0.addresseeID == currentUserID && $0.status == .pending
        }
        friendships.removeAll {
            $0.requesterID == userID && $0.addresseeID == currentUserID && $0.status == .pending
        }
        if isSyncConfigured, let id = inbound?.id { pushFriendshipStatus(id: id, status: .blocked) }
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

    // MARK: - Wishlist (Want to Try)

    var myWishlist: [WishlistItem] {
        wishlist
            .filter { $0.userID == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func isOnWishlist(shopID: UUID) -> Bool {
        wishlist.contains { $0.userID == currentUserID && $0.shopID == shopID }
    }

    @discardableResult
    func addWishlistItem(title: String, shopID: UUID? = nil, note: String = "") -> WishlistItem {
        let item = WishlistItem(
            id: UUID(),
            userID: currentUserID,
            shopID: shopID,
            title: title.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces),
            createdAt: .now
        )
        wishlist.append(item)
        if isSyncConfigured { pushWishlistItem(item) }
        return item
    }

    func removeWishlistItem(id: UUID) {
        wishlist.removeAll { $0.id == id && $0.userID == currentUserID }
        if isSyncConfigured { pushDeleteWishlistItem(id: id) }
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
        if isSyncConfigured { pushUpdateLog(updated) }
    }

    // Beli-style placement: after a binary-search comparison flow decides where a
    // new log ranks, set its ELO to sit between its neighbors and record the
    // comparisons that got it there (so those pairs aren't re-asked later).
    func applyPlacement(logID: UUID, score: Double, results: [(winner: UUID, loser: UUID)]) {
        guard let idx = drinkLogs.firstIndex(where: { $0.id == logID && $0.userID == currentUserID }) else { return }
        drinkLogs[idx].eloScore = score
        for r in results where !comparisons.contains(where: { $0.matches(r.winner, r.loser) }) {
            comparisons.append(
                Comparison(id: UUID(), userID: currentUserID, winnerLogID: r.winner, loserLogID: r.loser, comparedAt: .now)
            )
        }
        if isSyncConfigured { pushUpdateLog(drinkLogs[idx]) }
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

    // refreshFeed() and remote-write helpers live in AppStore+Sync.swift

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
        if isSyncConfigured { pushChatStatus(id: id, status: status) }
    }
}
