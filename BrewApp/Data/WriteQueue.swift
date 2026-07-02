import Foundation

// Offline write queue: when a mutation fails because the device has no
// network (not a server/auth error), it's persisted here instead of being
// silently dropped. The queue is drained automatically the next time a
// network call succeeds (refreshFeed), including across app relaunches.
enum PendingWrite: Codable {
    case insertLog(RemoteDrinkLog)
    case updateLog(RemoteDrinkLog)
    case deleteLog(id: String)
    case like(logID: String, userID: String)
    case unlike(logID: String, userID: String)
    case insertFriendship(RemoteFriendship)
    case friendshipStatus(id: String, status: String)
    case insertChatRequest(RemoteChatRequest)
    case chatStatus(id: String, status: String)
    case insertWishlistItem(RemoteWishlistItem)
    case deleteWishlistItem(id: String)
    case updateUsername(userID: String, username: String, displayName: String)
}

struct QueuedWrite: Codable, Identifiable {
    let id: UUID
    let queuedAt: Date
    let op: PendingWrite
}

@MainActor
final class WriteQueue {
    static let shared = WriteQueue()

    private(set) var items: [QueuedWrite] = []
    private let fileURL: URL

    var pendingCount: Int { items.count }

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("brew_pending_writes.json")
        load()
    }

    func enqueue(_ op: PendingWrite) {
        items.append(QueuedWrite(id: UUID(), queuedAt: .now, op: op))
        persist()
    }

    // Attempts each queued write in order. Stops at the first failure that is
    // itself a connectivity error (keeps remaining items queued); drops items
    // that fail for a non-network reason (e.g. now-invalid foreign key) so a
    // single bad row can't block the queue forever.
    func drain(supabase: SupabaseService, accessToken: String) async {
        guard !items.isEmpty else { return }
        var remaining = items
        while !remaining.isEmpty {
            let next = remaining[0]
            do {
                try await apply(next.op, supabase: supabase, accessToken: accessToken)
                remaining.removeFirst()
                items = remaining
                persist()
            } catch {
                if error is URLError {
                    // Still offline — leave remaining items queued for next attempt.
                    break
                }
                // Non-network failure (e.g. server rejected it) — drop and move on.
                remaining.removeFirst()
                items = remaining
                persist()
            }
        }
    }

    private func apply(_ op: PendingWrite, supabase: SupabaseService, accessToken: String) async throws {
        switch op {
        case .insertLog(let log):
            try await supabase.insertDrinkLog(log, accessToken: accessToken)
        case .updateLog(let log):
            try await supabase.updateDrinkLog(log, accessToken: accessToken)
        case .deleteLog(let id):
            guard let uuid = UUID(uuidString: id) else { return }
            try await supabase.deleteDrinkLog(id: uuid, accessToken: accessToken)
        case .like(let logID, let userID):
            guard let l = UUID(uuidString: logID), let u = UUID(uuidString: userID) else { return }
            try await supabase.insertLike(logID: l, userID: u, accessToken: accessToken)
        case .unlike(let logID, let userID):
            guard let l = UUID(uuidString: logID), let u = UUID(uuidString: userID) else { return }
            try await supabase.deleteLike(logID: l, userID: u, accessToken: accessToken)
        case .insertFriendship(let f):
            try await supabase.insertFriendship(f, accessToken: accessToken)
        case .friendshipStatus(let id, let status):
            guard let uuid = UUID(uuidString: id) else { return }
            try await supabase.updateFriendshipStatus(id: uuid, status: status, accessToken: accessToken)
        case .insertChatRequest(let r):
            try await supabase.insertChatRequest(r, accessToken: accessToken)
        case .chatStatus(let id, let status):
            guard let uuid = UUID(uuidString: id) else { return }
            try await supabase.updateChatRequestStatus(id: uuid, status: status, accessToken: accessToken)
        case .insertWishlistItem(let item):
            try await supabase.insertWishlistItem(item, accessToken: accessToken)
        case .deleteWishlistItem(let id):
            guard let uuid = UUID(uuidString: id) else { return }
            try await supabase.deleteWishlistItem(id: uuid, accessToken: accessToken)
        case .updateUsername(let userID, let username, let displayName):
            guard let uuid = UUID(uuidString: userID) else { return }
            try await supabase.updateUsername(userID: uuid, username: username, displayName: displayName, accessToken: accessToken)
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        items = (try? JSONDecoder().decode([QueuedWrite].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
