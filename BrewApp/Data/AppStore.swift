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
    var blockedUserIDs: Set<UUID> = []

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

    // Adds a real-world shop discovered via MapKit search (or re-selects an
    // already-known one) into the local cache, and syncs it to the shared
    // shops directory so friends can resolve its name/address too.
    func registerShop(_ shop: Shop) {
        if let idx = shops.firstIndex(where: { $0.id == shop.id }) {
            shops[idx] = shop
        } else {
            shops.append(shop)
        }
        if isSyncConfigured { pushShop(shop) }
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
            requestedAt: Date()
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
                comparedAt: Date()
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
        // Downscale/compress before caching or uploading — a raw photo
        // library image can be several MB, which is wasteful for a small
        // circular avatar and slow to upload.
        let compressed = Self.compressedAvatarData(data) ?? data
        avatarImages[currentUserID] = compressed
        if isSyncConfigured { pushAvatar(compressed) }
    }

    private static func compressedAvatarData(_ data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: 0.8)
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

    // MARK: - Blocking & Reporting (Apple Guideline 1.2)

    func isBlocked(_ userID: UUID) -> Bool {
        blockedUserIDs.contains(userID)
    }

    func blockUser(_ userID: UUID) {
        guard userID != currentUserID else { return }
        blockedUserIDs.insert(userID)
        // A block also severs any existing friendship/chat connection immediately.
        friendships.removeAll {
            ($0.requesterID == currentUserID && $0.addresseeID == userID) ||
            ($0.requesterID == userID && $0.addresseeID == currentUserID)
        }
        drinkLogs.removeAll { $0.userID == userID }
        chatRequests.removeAll { $0.requesterID == userID || $0.addresseeID == userID }
        if isSyncConfigured { pushBlock(userID) }
    }

    func unblockUser(_ userID: UUID) {
        blockedUserIDs.remove(userID)
        if isSyncConfigured { pushUnblock(userID) }
    }

    func reportUser(_ userID: UUID, reason: String) {
        if isSyncConfigured { pushReport(reportedUserID: userID, reportedLogID: nil, reason: reason) }
    }

    func reportLog(_ logID: UUID, reason: String) {
        if isSyncConfigured { pushReport(reportedUserID: nil, reportedLogID: logID, reason: reason) }
    }

    // MARK: - Suggested Friends (friends-of-friends)

    // In sync mode this needs a privileged server-side computation (RLS
    // only lets a user see their own friendship rows, not their friends'
    // other friendships) — see AppStore+Sync.fetchSuggestedFriendsRemote.
    // In demo mode the full mock friendship graph is already local, so it's
    // computed directly here.
    func suggestedFriendsLocal(limit: Int = 10) -> [(user: BrewUser, mutualCount: Int)] {
        let myFriendIDs = Set(
            friendships.filter { $0.status == .accepted }
                .flatMap { [$0.requesterID, $0.addresseeID] }
        ).subtracting([currentUserID])

        let excluded = myFriendIDs.union([currentUserID]).union(blockedUserIDs).union(
            friendships.filter { $0.status == .pending }.flatMap { [$0.requesterID, $0.addresseeID] }
        )

        var mutualCounts: [UUID: Int] = [:]
        for friendID in myFriendIDs {
            let theirFriends = friendships
                .filter { $0.status == .accepted && ($0.requesterID == friendID || $0.addresseeID == friendID) }
                .flatMap { [$0.requesterID, $0.addresseeID] }
                .filter { $0 != friendID }
            for candidate in theirFriends where !excluded.contains(candidate) {
                mutualCounts[candidate, default: 0] += 1
            }
        }

        return mutualCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { id, count in user(id: id).map { (user: $0, mutualCount: count) } }
    }

    // MARK: - Wishlist (Want to Try)

    var myWishlist: [WishlistItem] {
        wishlist
            .filter { (item: WishlistItem) in item.userID == currentUserID }
            .sorted { (lhs: WishlistItem, rhs: WishlistItem) in lhs.createdAt > rhs.createdAt }
    }

    func isOnWishlist(shopID: UUID) -> Bool {
        return wishlist.contains { (item: WishlistItem) in item.userID == currentUserID && item.shopID == shopID }
    }

    @discardableResult
    func addWishlistItem(title: String, shopID: UUID? = nil, note: String = "") -> WishlistItem {
        let item = WishlistItem(
            id: UUID(),
            userID: currentUserID,
            shopID: shopID,
            title: title.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces),
            createdAt: Date()
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
            .sorted { (lhs: DrinkLog, rhs: DrinkLog) in
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
                Comparison(id: UUID(), userID: currentUserID, winnerLogID: r.winner, loserLogID: r.loser, comparedAt: Date())
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
            events.append(ActivityEvent(kind: .friendRequest(f), date: Date()))
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

        return events.sorted { (a: ActivityEvent, b: ActivityEvent) in a.date > b.date }
    }

    // MARK: - People Search (Friends)

    /// Search users by username or display name. In sync mode, this may call the backend.
    func searchUsers(matching query: String) async -> [BrewUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // If sync is configured, attempt a remote search via Supabase; otherwise fall back to local.
        if isSyncConfigured {
            if let remote = await remoteSearchUsers(matching: trimmed) {
                return remote
            }
        }
        // Local fallback: filter the in-memory users array (excluding current user).
        let lower = trimmed.lowercased()
        return users
            .filter { $0.id != currentUserID }
            .filter { user in
                user.displayName.lowercased().contains(lower) ||
                user.username.lowercased().contains(lower)
            }
    }

    /// Upserts a user into the local cache (used when remote search returns unknown users).
    func upsertLocalUser(_ user: BrewUser) {
        if let idx = users.firstIndex(where: { $0.id == user.id }) {
            users[idx] = user
        } else {
            users.append(user)
        }
    }

    /// Attempt a remote user search when sync is configured. Returns nil if not available.
    private func remoteSearchUsers(matching query: String) async -> [BrewUser]? {
        // If there's no Supabase service, bail out.
        guard let supabase, let accessToken else { return nil }
        do {
            let results = try await supabase.searchUsers(accessToken: accessToken, query: query)
            return results
        } catch {
            // Swallow errors and let the caller fall back to local search.
            return nil
        }
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

