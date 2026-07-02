import Foundation

// MARK: - Configuration
enum SupabaseConfig {
    static let projectURL = "https://yunrgtoyizzohxuycqhq.supabase.co"
    // anon key is safe to ship in the client bundle; RLS policies protect data
    static let anonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1bnJndG95aXp6b2h4dXljcWhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5Mjk4OTEsImV4cCI6MjA5ODUwNTg5MX0.SfRJSZSgbjXt5Y1Cax_MnNRVFiVp-IGnmFDSosBBzy4"
}

// MARK: - SupabaseService

@Observable
final class SupabaseService {

    enum SupabaseError: LocalizedError {
        case notConfigured
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase credentials not configured."
            case .httpError(let code, let message):
                return "HTTP \(code): \(message)"
            }
        }
    }

    // MARK: - Auth

    func signInWithApple(identityToken: String) async throws -> SupabaseSession {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=id_token")!
        return try await post(url: url, body: ["provider": "apple", "id_token": identityToken], requiresAuth: false)
    }

    func signInWithEmail(email: String, password: String) async throws -> SupabaseSession {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=password")!
        return try await post(url: url, body: ["email": email, "password": password], requiresAuth: false)
    }

    func signUpWithEmail(email: String, password: String) async throws -> SupabaseSession {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/signup")!
        return try await post(url: url, body: ["email": email, "password": password], requiresAuth: false)
    }

    func signOut(accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Profiles

    func fetchProfile(userID: UUID, accessToken: String) async throws -> RemoteUser {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/profiles?id=eq.\(userID)&limit=1")!
        let results: [RemoteUser] = try await get(url: url, accessToken: accessToken)
        guard let profile = results.first else {
            throw SupabaseError.httpError(404, "Profile not found")
        }
        return profile
    }

    func upsertUserProfile(_ profile: RemoteUser, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/profiles")!
        var req = baseRequest(url: url, method: "POST", accessToken: accessToken)
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: profile.asDictionary())
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Drink Logs

    func fetchDrinkLogs(userID: UUID, accessToken: String) async throws -> [RemoteDrinkLog] {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/drink_logs?user_id=eq.\(userID)&order=logged_at.desc")!
        return try await get(url: url, accessToken: accessToken)
    }

    func fetchFeedLogs(friendIDs: [UUID], accessToken: String) async throws -> [RemoteDrinkLog] {
        guard !friendIDs.isEmpty else { return [] }
        let ids = friendIDs.map { $0.uuidString }.joined(separator: ",")
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/drink_logs?user_id=in.(\(ids))&order=logged_at.desc&limit=100")!
        return try await get(url: url, accessToken: accessToken)
    }

    func insertDrinkLog(_ log: RemoteDrinkLog, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/drink_logs")!
        let _: EmptyResponse = try await post(url: url, body: log.asDictionary(), accessToken: accessToken)
    }

    func updateDrinkLog(_ log: RemoteDrinkLog, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/drink_logs?id=eq.\(log.id)")!
        var req = baseRequest(url: url, method: "PATCH", accessToken: accessToken)
        req.httpBody = try JSONSerialization.data(withJSONObject: log.asDictionary())
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Friendships

    func fetchFriendships(userID: UUID, accessToken: String) async throws -> [RemoteFriendship] {
        let encoded = userID.uuidString
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/friendships?or=(requester_id.eq.\(encoded),addressee_id.eq.\(encoded))")!
        return try await get(url: url, accessToken: accessToken)
    }

    func insertFriendship(_ friendship: RemoteFriendship, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/friendships")!
        let _: EmptyResponse = try await post(url: url, body: friendship.asDictionary(), accessToken: accessToken)
    }

    func updateFriendshipStatus(id: UUID, status: String, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/friendships?id=eq.\(id)")!
        var req = baseRequest(url: url, method: "PATCH", accessToken: accessToken)
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Chat Requests

    func fetchChatRequests(userID: UUID, accessToken: String) async throws -> [RemoteChatRequest] {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/chat_requests?addressee_id=eq.\(userID)&status=eq.pending")!
        return try await get(url: url, accessToken: accessToken)
    }

    func insertChatRequest(_ request: RemoteChatRequest, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/chat_requests")!
        let _: EmptyResponse = try await post(url: url, body: request.asDictionary(), accessToken: accessToken)
    }

    func updateChatRequestStatus(id: UUID, status: String, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/chat_requests?id=eq.\(id)")!
        var req = baseRequest(url: url, method: "PATCH", accessToken: accessToken)
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Likes

    func fetchLikes(logIDs: [UUID], accessToken: String) async throws -> [RemoteLike] {
        guard !logIDs.isEmpty else { return [] }
        let ids = logIDs.map { $0.uuidString }.joined(separator: ",")
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/likes?log_id=in.(\(ids))")!
        return try await get(url: url, accessToken: accessToken)
    }

    func insertLike(logID: UUID, userID: UUID, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/likes")!
        let _: EmptyResponse = try await post(
            url: url,
            body: ["id": UUID().uuidString, "log_id": logID.uuidString, "user_id": userID.uuidString],
            accessToken: accessToken
        )
    }

    func deleteLike(logID: UUID, userID: UUID, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/likes?log_id=eq.\(logID)&user_id=eq.\(userID)")!
        var req = baseRequest(url: url, method: "DELETE", accessToken: accessToken)
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Private Helpers

    private func baseRequest(url: URL, method: String, accessToken: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func get<T: Decodable>(url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.supabase.decode(T.self, from: data)
    }

    private func post<T: Decodable>(url: URL, body: [String: Any], requiresAuth: Bool = true, accessToken: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.supabase.decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(http.statusCode, message)
        }
    }
}

// MARK: - Remote DTOs

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: UserPayload

    var userID: String { user.id }

    struct UserPayload: Codable {
        let id: String
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct RemoteUser: Codable {
    var id: String
    var username: String
    var displayName: String
    var isPublic: Bool
    var appearInChats: Bool

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case isPublic = "is_public"
        case appearInChats = "appear_in_chats"
    }

    func asDictionary() -> [String: Any] {
        ["id": id, "username": username, "display_name": displayName,
         "is_public": isPublic, "appear_in_chats": appearInChats]
    }
}

struct RemoteDrinkLog: Codable {
    var id: String
    var userID: String
    var shopID: String?
    var isHomeBrew: Bool
    var drinkName: String
    var brewMethod: String
    var roast: String
    var sweetness: Int
    var strength: Int
    var wouldOrder: String
    var notes: String
    var eloScore: Double
    var loggedAt: String
    var flavorTags: [[String: String]]?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case shopID = "shop_id"
        case isHomeBrew = "is_home_brew"
        case drinkName = "drink_name"
        case brewMethod = "brew_method"
        case roast, sweetness, strength
        case wouldOrder = "would_order"
        case notes
        case eloScore = "elo_score"
        case loggedAt = "logged_at"
        case flavorTags = "flavor_tags"
    }

    func asDictionary() -> [String: Any] {
        var d: [String: Any] = [
            "id": id, "user_id": userID, "is_home_brew": isHomeBrew,
            "drink_name": drinkName, "brew_method": brewMethod, "roast": roast,
            "sweetness": sweetness, "strength": strength,
            "would_order": wouldOrder, "notes": notes,
            "elo_score": eloScore, "logged_at": loggedAt
        ]
        if let shopID { d["shop_id"] = shopID }
        if let flavorTags { d["flavor_tags"] = flavorTags }
        return d
    }
}

struct RemoteFriendship: Codable {
    var id: String
    var requesterID: String
    var addresseeID: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
    }

    func asDictionary() -> [String: Any] {
        ["id": id, "requester_id": requesterID, "addressee_id": addresseeID, "status": status]
    }
}

struct RemoteChatRequest: Codable {
    var id: String
    var requesterID: String
    var addresseeID: String
    var shopID: String
    var status: String
    var requestedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case shopID = "shop_id"
        case status
        case requestedAt = "requested_at"
    }

    func asDictionary() -> [String: Any] {
        ["id": id, "requester_id": requesterID, "addressee_id": addresseeID,
         "shop_id": shopID, "status": status, "requested_at": requestedAt]
    }
}

struct RemoteLike: Codable {
    var id: String
    var logID: String
    var userID: String

    enum CodingKeys: String, CodingKey {
        case id
        case logID = "log_id"
        case userID = "user_id"
    }
}

private struct EmptyResponse: Codable {}

private extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
