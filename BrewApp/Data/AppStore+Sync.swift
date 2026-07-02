import Foundation

// Supabase sync layer for AppStore.
// All remote writes are fire-and-forget with optimistic local updates already
// applied by the caller. refreshFeed() is the single source of truth on pull.
// When the store is not sync-configured (demo mode) every method here no-ops.
// Writes that fail purely due to connectivity (no server/auth error) are
// persisted to WriteQueue and replayed automatically on the next successful
// network round trip — see runRemote / refreshFeed.
extension AppStore {

    // MARK: - Configuration

    @MainActor
    func configureSync(supabase: SupabaseService, session: SupabaseSession) async {
        guard let uid = UUID(uuidString: session.userID) else { return }
        self.supabase = supabase
        self.accessToken = session.accessToken
        self.authUserID = uid
        self.currentUserID = uid
        // Drop seeded mock comparisons so they don't leak into a real account.
        // (eloScore itself is persisted per drink_log, so rankings survive.)
        self.comparisons = []

        // Load this user's own profile so their name/username render correctly.
        do {
            let profile = try await supabase.fetchProfile(userID: uid, accessToken: session.accessToken)
            if let user = profile.toBrewUser(isCurrentUser: true) {
                upsertLocalUser(user)
            }
        } catch {
            // Profile row may not exist yet (created async by the signup trigger); ignore.
        }

        await refreshFeed()
    }

    func teardownSync() {
        supabase = nil
        accessToken = nil
        authUserID = nil
        syncError = nil
        isSyncing = false
    }

    // MARK: - Refresh (pull)

    func refreshFeed() async {
        await refreshFeed(attemptRefresh: true)
    }

    func refreshFeed(attemptRefresh: Bool) async {
        guard let supabase, let token = accessToken, let uid = authUserID else { return }
        await MainActor.run { self.isSyncing = true; self.syncError = nil }

        // Any writes queued while offline get a chance to flush before we pull,
        // so the fetch below reflects them.
        await WriteQueue.shared.drain(supabase: supabase, accessToken: token)

        do {
            let remoteFriendships = try await supabase.fetchFriendships(userID: uid, accessToken: token)
            let friendships = remoteFriendships
                .compactMap { $0.toFriendship() }
                .filter { $0.status == .pending || $0.status == .accepted }

            let acceptedFriendIDs = Set(
                friendships
                    .filter { $0.status == .accepted }
                    .flatMap { [$0.requesterID, $0.addresseeID] }
            ).subtracting([uid])

            async let myLogsTask = supabase.fetchDrinkLogs(userID: uid, accessToken: token)
            async let friendLogsTask = supabase.fetchFeedLogs(friendIDs: Array(acceptedFriendIDs), accessToken: token)
            async let chatsTask = supabase.fetchChatRequests(userID: uid, accessToken: token)
            let (remoteMine, remoteFriends, remoteChats) = try await (myLogsTask, friendLogsTask, chatsTask)

            var logsByID: [UUID: DrinkLog] = [:]
            for r in (remoteMine + remoteFriends) {
                if let log = r.toDrinkLog() { logsByID[log.id] = log }
            }
            let logs = logsByID.values.sorted { $0.loggedAt > $1.loggedAt }
            let chats = remoteChats.compactMap { $0.toChatRequest() }

            // Profiles for everyone referenced by logs / friendships / chats.
            let referencedIDs = Set(logs.map(\.userID))
                .union(friendships.flatMap { [$0.requesterID, $0.addresseeID] })
                .union(chats.flatMap { [$0.requesterID, $0.addresseeID] })
                .subtracting([uid])
            let profiles = (try? await supabase.fetchProfiles(ids: Array(referencedIDs), accessToken: token)) ?? []
            let fetchedUsers = profiles.compactMap { $0.toBrewUser() }

            // Likes for all visible logs.
            let likeRows = (try? await supabase.fetchLikes(logIDs: logs.map(\.id), accessToken: token)) ?? []
            var counts: [UUID: Int] = [:]
            var mine: Set<UUID> = []
            for row in likeRows {
                guard let logUUID = UUID(uuidString: row.logID) else { continue }
                counts[logUUID, default: 0] += 1
                if UUID(uuidString: row.userID) == uid { mine.insert(logUUID) }
            }

            let wishItems = ((try? await supabase.fetchWishlist(userID: uid, accessToken: token)) ?? [])
                .compactMap { $0.toWishlistItem() }

            await MainActor.run {
                self.drinkLogs = logs
                self.friendships = friendships
                self.chatRequests = chats
                for u in fetchedUsers { self.upsertLocalUser(u) }
                self.likeCounts = counts
                self.likedLogIDs = mine
                self.wishlist = wishItems
                self.isSyncing = false
            }
        } catch {
            if attemptRefresh, Self.isUnauthorized(error), let newToken = await tokenRefresher?() {
                await MainActor.run { self.accessToken = newToken }
                await refreshFeed(attemptRefresh: false)
                return
            }
            await MainActor.run {
                self.syncError = Self.isOffline(error) ? "Offline — changes will sync automatically" : Self.describe(error)
                self.isSyncing = false
            }
        }
    }

    // upsertLocalUser lives in AppStore.swift.

    // MARK: - Push helpers (fire-and-forget, queued while offline)

    private func runRemote(
        retryable: PendingWrite? = nil,
        _ op: @escaping (SupabaseService, String) async throws -> Void
    ) {
        guard let supabase, let token = accessToken else { return }
        Task {
            do {
                try await op(supabase, token)
            } catch {
                // On an expired token, refresh once and retry.
                if Self.isUnauthorized(error), let newToken = await self.tokenRefresher?() {
                    await MainActor.run { self.accessToken = newToken }
                    do { try await op(supabase, newToken); return }
                    catch { /* fall through — treat as a fresh failure below */ }
                }
                if Self.isOffline(error), let retryable {
                    await WriteQueue.shared.enqueue(retryable)
                    await MainActor.run { self.syncError = "Offline — changes will sync automatically" }
                } else {
                    await MainActor.run { self.syncError = Self.describe(error) }
                }
            }
        }
    }

    func pushInsertLog(_ log: DrinkLog) {
        let remote = RemoteDrinkLog(log)
        runRemote(retryable: .insertLog(remote)) { try await $0.insertDrinkLog(remote, accessToken: $1) }
    }

    func pushUpdateLog(_ log: DrinkLog) {
        let remote = RemoteDrinkLog(log)
        runRemote(retryable: .updateLog(remote)) { try await $0.updateDrinkLog(remote, accessToken: $1) }
    }

    func pushDeleteLog(id: UUID) {
        runRemote(retryable: .deleteLog(id: id.uuidString)) { try await $0.deleteDrinkLog(id: id, accessToken: $1) }
    }

    func pushLike(logID: UUID, liked: Bool) {
        guard let uid = authUserID else { return }
        let retry: PendingWrite = liked
            ? .like(logID: logID.uuidString, userID: uid.uuidString)
            : .unlike(logID: logID.uuidString, userID: uid.uuidString)
        runRemote(retryable: retry) { svc, token in
            if liked {
                try await svc.insertLike(logID: logID, userID: uid, accessToken: token)
            } else {
                try await svc.deleteLike(logID: logID, userID: uid, accessToken: token)
            }
        }
    }

    func pushFriendship(_ f: Friendship) {
        let remote = RemoteFriendship(f)
        runRemote(retryable: .insertFriendship(remote)) { try await $0.insertFriendship(remote, accessToken: $1) }
    }

    func pushFriendshipStatus(id: UUID, status: Friendship.Status) {
        runRemote(retryable: .friendshipStatus(id: id.uuidString, status: status.rawValue)) {
            try await $0.updateFriendshipStatus(id: id, status: status.rawValue, accessToken: $1)
        }
    }

    func pushChatRequest(_ r: CoffeeChatRequest) {
        let remote = RemoteChatRequest(r)
        runRemote(retryable: .insertChatRequest(remote)) { try await $0.insertChatRequest(remote, accessToken: $1) }
    }

    func pushChatStatus(id: UUID, status: CoffeeChatRequest.Status) {
        runRemote(retryable: .chatStatus(id: id.uuidString, status: status.rawValue)) {
            try await $0.updateChatRequestStatus(id: id, status: status.rawValue, accessToken: $1)
        }
    }

    func pushWishlistItem(_ item: WishlistItem) {
        let remote = RemoteWishlistItem(item)
        runRemote(retryable: .insertWishlistItem(remote)) { try await $0.insertWishlistItem(remote, accessToken: $1) }
    }

    func pushDeleteWishlistItem(id: UUID) {
        runRemote(retryable: .deleteWishlistItem(id: id.uuidString)) { try await $0.deleteWishlistItem(id: id, accessToken: $1) }
    }

    // searchUsers(matching:) lives in AppStore.swift.

    // MARK: - Username

    func updateUsername(_ username: String, displayName: String) {
        guard let uid = authUserID else { return }
        if let idx = users.firstIndex(where: { $0.id == uid }) {
            users[idx].username = username
            users[idx].displayName = displayName
        }
        runRemote(retryable: .updateUsername(userID: uid.uuidString, username: username, displayName: displayName)) {
            try await $0.updateUsername(userID: uid, username: username, displayName: displayName, accessToken: $1)
        }
    }

    // MARK: - Helpers

    static func describe(_ error: Error) -> String {
        (error as? SupabaseService.SupabaseError)?.errorDescription ?? error.localizedDescription
    }

    static func isUnauthorized(_ error: Error) -> Bool {
        if let e = error as? SupabaseService.SupabaseError, case .httpError(let code, _) = e {
            return code == 401 || code == 403
        }
        return false
    }

    static func isOffline(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}
